// ╔══════════════════════════════════════════════════════════════╗
// ║  features/files/files_provider.dart                          ║
// ║                                                              ║
// ║  Equivale al estado local de FilesPage en files.tsx.         ║
// ║                                                              ║
// ║  En React todo el estado estaba dentro del componente:       ║
// ║    const [dirs, setDirs] = useState([])                      ║
// ║    const [files, setFiles] = useState([])                    ║
// ║    const [crumbs, setCrumbs] = useState([...])               ║
// ║    const [loading, setLoading] = useState(false)             ║
// ║                                                              ║
// ║  En Flutter lo movemos a un Provider separado para que       ║
// ║  la pantalla quede más limpia y el estado sobreviva          ║
// ║  reconstrucciones del widget.                                ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/api/api_client.dart';
import '../../core/api/directory_api.dart';
import '../../core/api/file_api.dart';
import '../../core/models/archive_dto.dart';
import '../../core/models/directory_dto.dart';

/// Una "miga de pan" (breadcrumb) para la navegación de carpetas.
/// Equivale a { id: string | null; name: string } en files.tsx.
class Crumb {
  final String? id;   // null = raíz
  final String name;
  const Crumb({this.id, required this.name});
}

class FilesProvider extends ChangeNotifier {
  final DirectoryApi _dirApi;
  final FileApi _fileApi;

  // ── Estado equivalente a los useState de files.tsx ───────────────────────

  // Ruta de navegación actual (breadcrumbs)
  // Equivale a: const [crumbs, setCrumbs] = useState([{ id: null, name: 'Inicio' }])
  List<Crumb> _crumbs = [const Crumb(id: null, name: 'Inicio')];
  List<Crumb> get crumbs => _crumbs;

  // Carpetas del directorio actual
  List<DirectoryDto> _dirs = [];
  List<DirectoryDto> get dirs => _dirs;

  // Archivos del directorio actual
  List<ArchiveDto> _files = [];
  List<ArchiveDto> get files => _files;

  // Todas las carpetas (para el diálogo de mover)
  List<DirectoryDto> _allDirs = [];
  List<DirectoryDto> get allDirs => _allDirs;

  // Texto de búsqueda/filtro
  String _query = '';
  String get query => _query;

  bool _loading = false;
  bool get loading => _loading;

  bool _uploading = false;
  bool get uploading => _uploading;

  // Progreso de upload (0.0 - 1.0)
  double _uploadProgress = 0;
  double get uploadProgress => _uploadProgress;

  // Mensaje de error
  String? _error;
  String? get error => _error;

  // Mensaje de éxito (para "Descarga completada")
  String? _successMessage;
  String? get successMessage => _successMessage;

  FilesProvider(ApiClient client)
      : _dirApi = DirectoryApi(client),
        _fileApi = FileApi(client);

  // ── Getters derivados (equivale a variables calculadas en React) ──────────

  /// ID de la carpeta actual (null = raíz)
  String? get currentDirId => _crumbs.last.id;

  /// Carpetas filtradas por query
  List<DirectoryDto> get filteredDirs => _dirs
      .where((d) =>
          d.directoryName.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  /// Archivos filtrados por query
  List<ArchiveDto> get filteredFiles => _files
      .where((f) =>
          f.archiveName.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  // ── Carga de datos ────────────────────────────────────────────────────────

  /// Carga el contenido del directorio actual.
  /// Equivale a loadCurrentDir() en files.tsx.
  Future<void> loadCurrentDir() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // Equivale a Promise.all([dirApi.list..., fileApi.list(...)]) en React
      final results = await Future.wait([
        currentDirId != null
            ? _dirApi.listChildren(currentDirId!)
            : _dirApi.listRoot(),
        _fileApi.list(directoryId: currentDirId),
      ]);

      _dirs = results[0] as List<DirectoryDto>;
      _files = results[1] as List<ArchiveDto>;
    } on ApiError catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Carga recursivamente TODAS las carpetas (para el diálogo de mover).
  /// Equivale a loadAllDirs() en files.tsx.
  Future<void> loadAllDirs({String? parentId, String prefix = ''}) async {
    if (parentId == null && prefix.isEmpty) {
      _allDirs = []; // Reset al inicio de la carga
    }

    final dirs = parentId != null
        ? await _dirApi.listChildren(parentId)
        : await _dirApi.listRoot();

    for (final d in dirs) {
      _allDirs.add(DirectoryDto(
        directoryId: d.directoryId,
        directoryName: prefix + d.directoryName,
        userId: d.userId,
      ));
      await loadAllDirs(parentId: d.directoryId, prefix: '$prefix${d.directoryName} / ');
    }

    notifyListeners();
  }

  // ── Navegación (Breadcrumbs) ───────────────────────────────────────────────

  /// Navega a una carpeta del breadcrumb por índice.
  /// Equivale a navTo(idx) en files.tsx.
  Future<void> navTo(int idx) async {
    _crumbs = _crumbs.sublist(0, idx + 1);
    notifyListeners();
    await loadCurrentDir();
  }

  /// Abre una subcarpeta.
  /// Equivale a openDir(d) en files.tsx.
  Future<void> openDir(DirectoryDto d) async {
    _crumbs = [..._crumbs, Crumb(id: d.directoryId, name: d.directoryName)];
    notifyListeners();
    await loadCurrentDir();
  }

  // ── Búsqueda ──────────────────────────────────────────────────────────────

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  // ── CRUD Carpetas ─────────────────────────────────────────────────────────

  Future<void> createFolder(String name) async {
    await _dirApi.create(name, parentId: currentDirId);
    await loadCurrentDir();
  }

  Future<void> renameDir(String id, String name) async {
    await _dirApi.rename(id, name);
    await loadCurrentDir();
  }

  Future<void> deleteDir(String id) async {
    await _dirApi.delete(id);
    await loadCurrentDir();
  }

  // ── CRUD Archivos ─────────────────────────────────────────────────────────

  Future<void> uploadFiles(List<File> fileList) async {
    _uploading = true;
    _uploadProgress = 0;
    _error = null;
    notifyListeners();

    try {
      for (int i = 0; i < fileList.length; i++) {
        await _fileApi.upload(
          fileList[i],
          directoryId: currentDirId,
          onProgress: (p) {
            // Progreso total: fracción del archivo actual + archivos anteriores
            _uploadProgress = (i + p) / fileList.length;
            notifyListeners();
          },
        );
      }
      await loadCurrentDir();
    } on ApiError catch (e) {
      _error = e.message;
      notifyListeners();
    } finally {
      _uploading = false;
      _uploadProgress = 0;
      notifyListeners();
    }
  }

  Future<String> downloadFile(String archiveId) async {
    return await _fileApi.download(archiveId);
  }

  Future<void> renameFile(String id, String name) async {
    await _fileApi.rename(id, name);
    await loadCurrentDir();
  }

  Future<void> moveFile(String id, {String? directoryId}) async {
    await _fileApi.move(id, directoryId: directoryId);
    await loadCurrentDir();
  }

  Future<void> toggleVisibility(ArchiveDto file) async {
    await _fileApi.setVisibility(file.archiveId, isPublic: !file.isPublic);
    await loadCurrentDir();
  }

  Future<void> deleteFile(String id) async {
    await _fileApi.delete(id);
    await loadCurrentDir();
  }

  // ── Utilidades ────────────────────────────────────────────────────────────

  void showSuccess(String msg) {
    _successMessage = msg;
    notifyListeners();
    Future.delayed(const Duration(seconds: 3), () {
      _successMessage = null;
      notifyListeners();
    });
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String getShareUrl(String? shareToken) {
    if (shareToken == null) return '';
    return '${ApiClient.baseUrl}/file/download/shared/$shareToken';
  }
}
