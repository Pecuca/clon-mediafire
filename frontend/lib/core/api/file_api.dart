// ╔══════════════════════════════════════════════════════════════╗
// ║  api/file_api.dart — Operaciones de archivos                ║
// ║                                                              ║
// ║  Equivale a fileApi en api.ts. Incluye la lógica de         ║
// ║  subida/descarga criptográfica integrada.                    ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';
import '../models/archive_dto.dart';
import '../crypto/crypto_service.dart';

class FileApi {
  final ApiClient _client;
  final CryptoService _crypto;

  FileApi(this._client) : _crypto = CryptoService();

  // ── Listar archivos ──────────────────────────────────────────────────────

  /// GET /file?directoryId=... — lista archivos de una carpeta
  /// Equivale a fileApi.list(directoryId) en api.ts
  Future<List<ArchiveDto>> list({String? directoryId}) async {
    final q = directoryId != null ? '?directoryId=$directoryId' : '?directoryId=root';
    final res = await _client.request<List<dynamic>>(
      method: 'GET',
      path: '/file$q',
    );
    return (res.data as List)
        .map((e) => ArchiveDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Subir archivo (con criptografía) ────────────────────────────────────

  /// Sube un archivo aplicando el protocolo AES-256-GCM + RSA-OAEP.
  /// Equivale a fileApi.upload() en api.ts.
  ///
  /// Pasos:
  ///   1. POST /file/upload/init → obtiene token + llave pública del servidor
  ///   2. Encripta el archivo con AES-GCM
  ///   3. Encripta la AES key y el hash con RSA-OAEP
  ///   4. POST /file/upload con FormData multipart
  Future<ArchiveDto> upload(
    File file, {
    String? directoryId,
    void Function(double progress)? onProgress,
  }) async {
    // Paso 1: Iniciar upload — el servidor genera un par RSA temporal
    final initRes = await _client.request<Map<String, dynamic>>(
      method: 'POST',
      path: '/file/upload/init',
    );
    final uploadToken = initRes.data!['uploadToken'] as String;
    final serverPublicKeyPem = initRes.data!['publicKey'] as String;

    // Paso 2-5: Preparar payload criptográfico
    final fileBytes = await file.readAsBytes();
    final payload = _crypto.prepareUpload(
      fileBytes: fileBytes,
      serverPemKey: serverPublicKeyPem,
      fileName: p.basename(file.path),
    );

    // Paso 6: Construir FormData y enviar
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        payload.cipherText,
        filename: payload.fileName,
        contentType: DioMediaType('application', 'octet-stream'),
      ),
      'uploadToken': uploadToken,
      'encryptedSymmetricKey': payload.encryptedSymKey,
      'encryptedHash': payload.encryptedHash,
      if (directoryId != null) 'directoryId': directoryId,
    });

    final res = await _client.dio.post<Map<String, dynamic>>(
      '/file/upload',
      data: formData,
      onSendProgress: onProgress != null
          ? (sent, total) {
              if (total > 0) onProgress(sent / total);
            }
          : null,
    );

    if (res.statusCode == null || res.statusCode! >= 400) {
      final msg = (res.data as Map?)?['message'] as String? ??
          'Error al subir archivo';
      throw ApiError(msg, res.statusCode ?? 500);
    }

    return ArchiveDto.fromJson(res.data!);
  }

  // ── Descargar archivo (con criptografía) ─────────────────────────────────

  /// Descarga y desencripta un archivo aplicando el protocolo completo.
  ///
  /// Pasos:
  ///   1. GET /file/download-init/:id  → llave pública RSA del archivo
  ///   2. Generar llave AES del cliente (key + IV aleatorios)
  ///   3. Cifrar {key, IV} con RSA-OAEP usando la llave pública del servidor
  ///   4. GET /file/download/:id con header x-client-aes-key
  ///   5. Servidor re-cifra el archivo con la llave AES del cliente
  ///   6. Descifrar respuesta con la llave AES local
  ///   7. Verificar SHA-256 con el header x-file-hash
  ///   8. Guardar en carpeta de Descargas
  Future<String> download(String archiveId) async {
    // Paso 1: Obtener la llave pública RSA del archivo
    final initRes = await _client.request<Map<String, dynamic>>(
      method: 'GET',
      path: '/file/download-init/$archiveId',
    );
    final serverPublicKeyPem = initRes.data!['publicKey'] as String;

    // Paso 2: Generar llave AES del cliente (32 bytes key + 16 bytes IV)
    final clientAesKey = _crypto.generateClientAesKey();

    // Paso 3: Cifrar la llave AES con RSA-OAEP del servidor
    final encryptedClientKey =
        _crypto.encryptClientAesKeyForServer(serverPublicKeyPem, clientAesKey);

    // Paso 4: Descargar el archivo (el servidor lo re-cifra con nuestra llave AES)
    final res = await _client.dio.get<List<int>>(
      '/file/download/$archiveId',
      options: Options(
        headers: {'x-client-aes-key': encryptedClientKey},
        responseType: ResponseType.bytes,
        validateStatus: (_) => true,
      ),
    );

    if (res.statusCode == null || res.statusCode! >= 400) {
      throw ApiError('Error al descargar archivo', res.statusCode ?? 500);
    }

    // Paso 5: Leer el hash del plaintext desde los headers
    final expectedHash = res.headers.value('x-file-hash');
    if (expectedHash == null) {
      throw ApiError('Falta el header x-file-hash', 500);
    }

    // Obtener nombre del archivo desde Content-Disposition
    final disposition = res.headers.value('content-disposition') ?? '';
    final filename = _extractFilename(disposition);

    // Pasos 6-7: Descifrar con la llave AES local y verificar integridad
    final plainBytes = _crypto.decryptDownload(
      cipherTextWithTag: Uint8List.fromList(res.data!),
      clientKey: clientAesKey.key,
      clientIv: clientAesKey.iv,
      expectedHash: expectedHash,
    );

    // Paso 8: Guardar en la carpeta de Descargas del usuario
    final downloadsDir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final outFile = File(p.join(downloadsDir.path, filename));
    await outFile.writeAsBytes(plainBytes);

    return outFile.path;
  }

  // ── Renombrar archivo ────────────────────────────────────────────────────

  /// PUT /file/:id/rename
  Future<ArchiveDto> rename(String id, String name) async {
    final res = await _client.request<Map<String, dynamic>>(
      method: 'PUT',
      path: '/file/$id/rename',
      data: {'name': name},
    );
    return ArchiveDto.fromJson(res.data!);
  }

  // ── Mover archivo ────────────────────────────────────────────────────────

  /// PUT /file/:id/move
  Future<ArchiveDto> move(String id, {String? directoryId}) async {
    final res = await _client.request<Map<String, dynamic>>(
      method: 'PUT',
      path: '/file/$id/move',
      data: {'directoryId': directoryId},
    );
    return ArchiveDto.fromJson(res.data!);
  }

  // ── Cambiar visibilidad ──────────────────────────────────────────────────

  /// PUT /file/:id/visibility
  Future<ArchiveDto> setVisibility(String id, {required bool isPublic}) async {
    final res = await _client.request<Map<String, dynamic>>(
      method: 'PUT',
      path: '/file/$id/visibility',
      data: {'is_public': isPublic},
    );
    return ArchiveDto.fromJson(res.data!);
  }

  // ── Eliminar archivo ─────────────────────────────────────────────────────

  /// DELETE /file/:id
  Future<void> delete(String id) async {
    await _client.request<dynamic>(
      method: 'DELETE',
      path: '/file/$id',
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _extractFilename(String disposition) {
    // Intentar UTF-8 primero: filename*=UTF-8''...
    final utf8Match =
        RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false)
            .firstMatch(disposition);
    if (utf8Match != null) return Uri.decodeComponent(utf8Match.group(1)!);

    // Luego ASCII: filename="..."
    final asciiMatch =
        RegExp(r'filename="?([^";]+)"?', caseSensitive: false)
            .firstMatch(disposition);
    if (asciiMatch != null) return asciiMatch.group(1)!;

    return 'descarga';
  }
}
