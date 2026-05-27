// ╔══════════════════════════════════════════════════════════════╗
// ║  api/directory_api.dart — CRUD de carpetas                  ║
// ║                                                              ║
// ║  Equivale a dirApi en api.ts:                               ║
// ║    dirApi.listRoot()                                         ║
// ║    dirApi.listChildren(parentId)                             ║
// ║    dirApi.create(name, parentId)                             ║
// ║    dirApi.rename(id, name)                                   ║
// ║    dirApi.delete(id)                                         ║
// ╚══════════════════════════════════════════════════════════════╝

import 'api_client.dart';
import '../models/directory_dto.dart';

class DirectoryApi {
  final ApiClient _client;
  const DirectoryApi(this._client);

  /// GET /directory — lista carpetas raíz del usuario
  Future<List<DirectoryDto>> listRoot() async {
    final res = await _client.request<List<dynamic>>(
      method: 'GET',
      path: '/directory',
    );
    return (res.data as List)
        .map((e) => DirectoryDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /directory/:parentId — lista subcarpetas de una carpeta
  Future<List<DirectoryDto>> listChildren(String parentId) async {
    final res = await _client.request<List<dynamic>>(
      method: 'GET',
      path: '/directory/$parentId',
    );
    return (res.data as List)
        .map((e) => DirectoryDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /directory — crea una nueva carpeta
  Future<DirectoryDto> create(String name, {String? parentId}) async {
    final res = await _client.request<Map<String, dynamic>>(
      method: 'POST',
      path: '/directory',
      data: {'name': name, if (parentId != null) 'parentId': parentId},
    );
    return DirectoryDto.fromJson(res.data!);
  }

  /// PUT /directory/:id — renombra una carpeta
  Future<DirectoryDto> rename(String id, String name) async {
    final res = await _client.request<Map<String, dynamic>>(
      method: 'PUT',
      path: '/directory/$id',
      data: {'name': name},
    );
    return DirectoryDto.fromJson(res.data!);
  }

  /// DELETE /directory/:id — elimina una carpeta (y su contenido)
  Future<void> delete(String id) async {
    await _client.request<dynamic>(
      method: 'DELETE',
      path: '/directory/$id',
    );
  }
}
