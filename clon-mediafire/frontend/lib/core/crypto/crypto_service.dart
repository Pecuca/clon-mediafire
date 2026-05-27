// ╔══════════════════════════════════════════════════════════════╗
// ║  crypto/crypto_service.dart                                  ║
// ║                                                              ║
// ║  Esta es la parte más importante del proyecto.               ║
// ║  Implementa el mismo protocolo criptográfico que api.ts,     ║
// ║  pero en Dart usando la librería pointycastle.              ║
// ║                                                              ║
// ║  PROTOCOLO DE SUBIDA (Upload):                               ║
// ║    1. Generar AES-256-GCM key + IV aleatório                ║
// ║    2. Encriptar el archivo con AES-GCM                      ║
// ║    3. Calcular SHA-256 del plaintext (para verificar integ.) ║
// ║    4. Encriptar {key,iv,authTag} con RSA-OAEP del servidor  ║
// ║    5. Encriptar el hash SHA-256 con RSA-OAEP                ║
// ║                                                              ║
// ║  PROTOCOLO DE DESCARGA (Download):                           ║
// ║    1. Generar par RSA del cliente                            ║
// ║    2. El servidor encripta la AES key con la llave PÚBLICA  ║
// ║       del cliente                                            ║
// ║    3. Desencriptamos con nuestra llave PRIVADA              ║
// ║    4. Desencriptamos el archivo con AES-GCM                 ║
// ║    5. Verificamos SHA-256 para garantizar integridad         ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:crypto/crypto.dart' as pkg_crypto;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart';

// ── Tipos de datos ───────────────────────────────────────────────────────────

/// Resultado de encriptar un archivo (lo que se envía al servidor)
class EncryptedUploadPayload {
  final Uint8List cipherText;      // El archivo encriptado (sin authTag)
  final String encryptedSymKey;   // JSON {key,iv,authTag} encriptado con RSA
  final String encryptedHash;     // SHA-256 encriptado con RSA
  final String fileName;

  const EncryptedUploadPayload({
    required this.cipherText,
    required this.encryptedSymKey,
    required this.encryptedHash,
    required this.fileName,
  });
}

/// Par de llaves RSA del cliente para descifrar la respuesta del servidor
class ClientKeyPair {
  final RSAPrivateKey privateKey;
  final String publicKeyBase64; // Llave pública en formato Base64 SPKI

  const ClientKeyPair({
    required this.privateKey,
    required this.publicKeyBase64,
  });
}

/// Payload simétrico: la información para descifrar el archivo
class SymmetricPayload {
  final String key;     // AES key en hex
  final String iv;      // IV en hex
  final String authTag; // Authentication tag en hex

  const SymmetricPayload({
    required this.key,
    required this.iv,
    required this.authTag,
  });

  factory SymmetricPayload.fromJson(Map<String, dynamic> json) {
    return SymmetricPayload(
      key: json['key'] as String,
      iv: json['iv'] as String,
      authTag: json['authTag'] as String,
    );
  }
}

// ── CryptoService ─────────────────────────────────────────────────────────────

class CryptoService {
  final _random = FortunaRandom();

  CryptoService() {
    // Inicializa el generador de números aleatorios con entropía real
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    _random.seed(KeyParameter(Uint8List.fromList(seeds)));
  }

  // ── Helpers: conversiones hex/bytes/base64 ──────────────────────────────

  /// Convierte bytes a cadena hexadecimal (mismo que en api.ts)
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Convierte cadena hex a bytes
  Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  /// Genera bytes aleatorios seguros
  Uint8List _randomBytes(int count) {
    final bytes = Uint8List(count);
    for (int i = 0; i < count; i++) {
      bytes[i] = _random.nextUint8();
    }
    return bytes;
  }

  // ── SHA-256 ──────────────────────────────────────────────────────────────

  /// Calcula SHA-256 de los bytes dados y devuelve hex.
  /// Equivale a sha256Hex() en api.ts.
  String sha256Hex(Uint8List data) {
    final digest = pkg_crypto.sha256.convert(data);
    return digest.toString(); // ya devuelve hex
  }

  // ── AES-256-GCM ──────────────────────────────────────────────────────────

  /// Encripta datos con AES-256-GCM.
  /// Devuelve (cipherText, authTag) por separado, igual que en api.ts donde
  /// se hace slice(-16) para separar el tag del ciphertext.
  ({Uint8List cipherText, Uint8List authTag, Uint8List key, Uint8List iv})
      aesGcmEncrypt(Uint8List plaintext) {
    // Generar llave AES de 256 bits (32 bytes) aleatória
    final key = _randomBytes(32);
    // Generar IV de 16 bytes aleatório
    final iv = _randomBytes(16);

    // GCMBlockCipher de pointycastle
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      true, // true = encriptar
      AEADParameters(
        KeyParameter(key),
        128, // tagLength en bits
        iv,
        Uint8List(0), // AAD vacío
      ),
    );

    // Procesar: el output incluye cipherText + authTag concatenados
    final outputWithTag = Uint8List(cipher.getOutputSize(plaintext.length));
    final len = cipher.processBytes(plaintext, 0, plaintext.length, outputWithTag, 0);
    cipher.doFinal(outputWithTag, len);

    // Separar cipherText y authTag (el tag ocupa los últimos 16 bytes)
    final cipherText = outputWithTag.sublist(0, outputWithTag.length - 16);
    final authTag = outputWithTag.sublist(outputWithTag.length - 16);

    return (cipherText: cipherText, authTag: authTag, key: key, iv: iv);
  }

  /// Desencripta datos con AES-256-GCM y verifica el authTag automáticamente.
  /// Equivale a crypto.subtle.decrypt({name:'AES-GCM',...}) en api.ts.
  Uint8List aesGcmDecrypt({
    required Uint8List cipherText,
    required Uint8List authTag,
    required Uint8List key,
    required Uint8List iv,
  }) {
    // Concatenar cipherText + authTag (lo que espera GCMBlockCipher)
    final combined = Uint8List(cipherText.length + authTag.length)
      ..setAll(0, cipherText)
      ..setAll(cipherText.length, authTag);

    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      false, // false = desencriptar
      AEADParameters(
        KeyParameter(key),
        128,
        iv,
        Uint8List(0),
      ),
    );

    final output = Uint8List(cipher.getOutputSize(combined.length));
    final len = cipher.processBytes(combined, 0, combined.length, output, 0);
    cipher.doFinal(output, len);

    return output;
  }

  // ── RSA-OAEP ─────────────────────────────────────────────────────────────

  /// Importa la llave pública RSA del servidor desde formato PEM.
  /// Equivale a importServerPublicKey() en api.ts.
  RSAPublicKey importPublicKeyFromPem(String pem) {
    final parser = enc.RSAKeyParser();
    return parser.parse(pem) as RSAPublicKey;
  }

  /// Encripta datos con RSA-OAEP usando la llave pública del servidor.
  /// Equivale a encryptHeaderPayload() en api.ts.
  String rsaOaepEncrypt(RSAPublicKey publicKey, String payload) {
    final cipher = OAEPEncoding.withSHA256(RSAEngine());
    cipher.init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    final payloadBytes = utf8.encode(payload);
    final encrypted = cipher.process(Uint8List.fromList(payloadBytes));
    return base64.encode(encrypted);
  }

  // ── Par de llaves RSA del cliente (para descarga) ─────────────────────────

  /// Genera un par de llaves RSA-OAEP del cliente.
  /// Equivale a generateClientKeyPair() en api.ts.
  ClientKeyPair generateClientKeyPair() {
    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        _random,
      ));

    final pair = keyGen.generateKeyPair();
    final publicKey = pair.publicKey as RSAPublicKey;
    final privateKey = pair.privateKey as RSAPrivateKey;

    // Exportar llave pública a formato SPKI (Base64) para enviar al servidor
    final publicKeyBase64 = _exportPublicKeyToBase64(publicKey);

    return ClientKeyPair(privateKey: privateKey, publicKeyBase64: publicKeyBase64);
  }

  /// Exporta RSAPublicKey a Base64 SPKI (formato que entiende el servidor).
  String _exportPublicKeyToBase64(RSAPublicKey key) {
    // Construir ASN.1 SPKI manualmente usando asn1lib
    final algorithmSeq = ASN1Sequence()
      ..add(ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.1.1'))
      ..add(ASN1Null());

    final innerSeq = ASN1Sequence()
      ..add(ASN1Integer(key.modulus!))
      ..add(ASN1Integer(key.exponent!));

    final bitString = ASN1BitString(
      Uint8List.fromList([0, ...innerSeq.encodedBytes]),
    );

    final spki = ASN1Sequence()
      ..add(algorithmSeq)
      ..add(bitString);

    return base64.encode(spki.encodedBytes);
  }

  /// Desencripta datos con RSA-OAEP usando la llave privada del cliente.
  /// Equivale a decryptHeaderPayload() en api.ts.
  String rsaOaepDecrypt(RSAPrivateKey privateKey, String encryptedBase64) {
    final cipher = OAEPEncoding.withSHA256(RSAEngine());
    cipher.init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final encryptedBytes = base64.decode(encryptedBase64);
    final decrypted = cipher.process(Uint8List.fromList(encryptedBytes));
    return utf8.decode(decrypted);
  }

  // ── API de alto nivel: preparar upload ───────────────────────────────────

  /// Prepara el payload completo para subir un archivo.
  /// Esta función orquesta los pasos 2-6 del protocolo de subida.
  ///
  /// Parámetros:
  ///   fileBytes   — contenido del archivo en bytes
  ///   serverPemKey — llave pública RSA del servidor (recibida del backend)
  ///   fileName    — nombre del archivo
  EncryptedUploadPayload prepareUpload({
    required Uint8List fileBytes,
    required String serverPemKey,
    required String fileName,
  }) {
    // Paso 3: Calcular SHA-256 del archivo en texto plano
    final plainHash = sha256Hex(fileBytes);

    // Paso 2: Encriptar el archivo con AES-256-GCM
    final aesResult = aesGcmEncrypt(fileBytes);

    // Construir el payload simétrico (lo que va encriptado en el header)
    final symPayload = {
      'key': _bytesToHex(aesResult.key),
      'iv': _bytesToHex(aesResult.iv),
      'authTag': _bytesToHex(aesResult.authTag),
    };

    // Paso 4-5: Importar llave pública del servidor y encriptar
    final serverPublicKey = importPublicKeyFromPem(serverPemKey);
    final encryptedSymKey = rsaOaepEncrypt(serverPublicKey, jsonEncode(symPayload));
    final encryptedHash = rsaOaepEncrypt(serverPublicKey, plainHash);

    return EncryptedUploadPayload(
      cipherText: aesResult.cipherText,
      encryptedSymKey: encryptedSymKey,
      encryptedHash: encryptedHash,
      fileName: fileName,
    );
  }

  // ── API de alto nivel: desencriptar descarga ──────────────────────────────

  /// Desencripta y verifica un archivo descargado del servidor.
  /// Orquesta los pasos 3-5 del protocolo de descarga.
  ///
  /// Parámetros:
  ///   cipherText           — cuerpo de la respuesta (archivo encriptado)
  ///   encryptedSymKeyB64   — header x-crypto-symmetric-key
  ///   encryptedHashB64     — header x-file-hash
  ///   clientPrivateKey     — llave privada RSA del cliente
  ///
  /// Retorna los bytes del archivo original.
  Uint8List decryptDownload({
    required Uint8List cipherText,
    required String encryptedSymKeyB64,
    required String encryptedHashB64,
    required RSAPrivateKey clientPrivateKey,
  }) {
    // Desencriptar el payload simétrico con la llave privada del cliente
    final symPayloadJson = rsaOaepDecrypt(clientPrivateKey, encryptedSymKeyB64);
    final symPayload = SymmetricPayload.fromJson(
      jsonDecode(symPayloadJson) as Map<String, dynamic>,
    );

    // Desencriptar el hash
    final expectedHash = rsaOaepDecrypt(clientPrivateKey, encryptedHashB64);

    // Desencriptar el archivo con AES-GCM
    final plainBytes = aesGcmDecrypt(
      cipherText: cipherText,
      authTag: _hexToBytes(symPayload.authTag),
      key: _hexToBytes(symPayload.key),
      iv: _hexToBytes(symPayload.iv),
    );

    // Verificar integridad: SHA-256 del plaintext debe coincidir
    final actualHash = sha256Hex(plainBytes);
    if (actualHash != expectedHash.toLowerCase()) {
      throw Exception('Integridad comprometida: hash no coincide');
    }

    return plainBytes;
  }
}
