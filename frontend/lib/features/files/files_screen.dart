// ╔══════════════════════════════════════════════════════════════╗
// ║  features/files/files_screen.dart                            ║
// ║                                                              ║
// ║  Equivale a FilesPage en files.tsx — la pantalla principal. ║
// ║                                                              ║
// ║  Contiene: Header, Breadcrumbs, Búsqueda, Botones,          ║
// ║  DropZone, Tabla de archivos y carpetas, y todos los        ║
// ║  diálogos (eliminar, renombrar, mover).                     ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/models/archive_dto.dart';
import '../../core/models/directory_dto.dart';
import '../../core/providers/auth_provider.dart';
import 'files_provider.dart';

class FilesScreen extends StatelessWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Creamos FilesProvider aquí y lo pasamos al árbol de widgets.
    // ChangeNotifierProxyProvider necesita el ApiClient del contexto padre.
    return ChangeNotifierProvider(
      create: (ctx) {
        final provider = FilesProvider(ctx.read<ApiClient>());
        // Carga inicial al montar la pantalla
        // Equivale a useEffect(() => { loadCurrentDir() }, [user]) en React
        provider.loadCurrentDir();
        return provider;
      },
      child: const _FilesScreenContent(),
    );
  }
}

class _FilesScreenContent extends StatelessWidget {
  const _FilesScreenContent();

  @override
  Widget build(BuildContext context) {
    final files = context.watch<FilesProvider>();
    final auth = context.read<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          // Equivale a <header> en files.tsx
          _Header(
            userName: auth.user?.userName ?? '',
            onLogout: () => auth.logout(),
          ),

          // ── Barra de snackbar de éxito ───────────────────────────────
          if (files.successMessage != null)
            _SuccessBanner(message: files.successMessage!),

          // ── Contenido principal ──────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mis archivos',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(
                            '${files.dirs.length} carpetas · ${files.files.length} archivos',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Toolbar: Breadcrumb + Búsqueda + Botones ──────────
                  _Toolbar(
                    onPickFiles: () => _pickAndUpload(context),
                  ),
                  const SizedBox(height: 16),

                  // ── DropZone ───────────────────────────────────────────
                  _DropZone(onFiles: (f) => _uploadFiles(context, f)),
                  const SizedBox(height: 24),

                  // ── Tabla de archivos ──────────────────────────────────
                  _FileTable(
                    onDownload: (f) => _download(context, f),
                    onCopyLink: (f) => _copyLink(context, f),
                    onRenameFile: (f) => _showNameDialog(
                      context,
                      title: 'Renombrar archivo',
                      initial: f.archiveName,
                      onConfirm: (name) =>
                          context.read<FilesProvider>().renameFile(f.archiveId, name),
                    ),
                    onMoveFile: (f) => _showMoveDialog(context, f),
                    onDeleteFile: (f) => _showDeleteDialog(
                      context,
                      id: f.archiveId,
                      name: f.archiveName,
                      isDir: false,
                    ),
                    onRenameDir: (d) => _showNameDialog(
                      context,
                      title: 'Renombrar carpeta',
                      initial: d.directoryName,
                      onConfirm: (name) =>
                          context.read<FilesProvider>().renameDir(d.directoryId, name),
                    ),
                    onDeleteDir: (d) => _showDeleteDialog(
                      context,
                      id: d.directoryId,
                      name: d.directoryName,
                      isDir: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Handlers ──────────────────────────────────────────────────────────────

  Future<void> _pickAndUpload(BuildContext context) async {
    // file_picker abre el explorador de archivos nativo de Windows
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || !context.mounted) return;
    final fileList = result.paths
        .whereType<String>()
        .map((p) => File(p))
        .toList();
    await _uploadFiles(context, fileList);
  }

  Future<void> _uploadFiles(BuildContext context, List<File> fileList) async {
    if (fileList.isEmpty || !context.mounted) return;
    await context.read<FilesProvider>().uploadFiles(fileList);
  }

  Future<void> _download(BuildContext context, ArchiveDto f) async {
    if (!context.mounted) return;
    final prov = context.read<FilesProvider>();
    try {
      final path = await prov.downloadFile(f.archiveId);
      if (context.mounted) {
        prov.showSuccess('Archivo guardado en: $path');
      }
    } on ApiError catch (e) {
      if (context.mounted) {
        _showError(context, e.message);
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, e.toString());
      }
    }
  }

  void _copyLink(BuildContext context, ArchiveDto f) {
    if (f.shareToken == null) return;
    final url = context.read<FilesProvider>().getShareUrl(f.shareToken);
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace copiado al portapapeles')),
    );
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // ── Diálogos ──────────────────────────────────────────────────────────────

  /// Muestra el diálogo de renombrar / nueva carpeta.
  /// Equivale a los estados nameDialog en files.tsx.
  Future<void> _showNameDialog(
    BuildContext context, {
    required String title,
    required String initial,
    required Future<void> Function(String) onConfirm,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _NameDialog(controller: ctrl, title: title),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty && context.mounted) {
      await onConfirm(ctrl.text.trim());
    }
    ctrl.dispose();
  }

  /// Muestra el diálogo de confirmación de eliminación (3 pasos).
  /// Equivale a confirmStep en files.tsx.
  Future<void> _showDeleteDialog(
    BuildContext context, {
    required String id,
    required String name,
    required bool isDir,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(name: name, isDir: isDir),
    );
    if (confirmed == true && context.mounted) {
      final prov = context.read<FilesProvider>();
      try {
        if (isDir) {
          await prov.deleteDir(id);
        } else {
          await prov.deleteFile(id);
        }
      } on ApiError catch (e) {
        if (context.mounted) _showError(context, e.message);
      }
    }
  }

  /// Muestra el diálogo de mover archivo.
  Future<void> _showMoveDialog(BuildContext context, ArchiveDto f) async {
    final prov = context.read<FilesProvider>();
    await prov.loadAllDirs();

    if (!context.mounted) return;

    final destId = await showDialog<String>(
      context: context,
      builder: (_) => _MoveDialog(
        allDirs: prov.allDirs,
        currentDirId: f.directoryId,
      ),
    );

    if (destId != null && context.mounted) {
      await prov.moveFile(
        f.archiveId,
        directoryId: destId == 'root' ? null : destId,
      );
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS INTERNOS
// ══════════════════════════════════════════════════════════════════════════════

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String userName;
  final VoidCallback onLogout;
  const _Header({required this.userName, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.cloud_upload_outlined,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('ColapsoLoad',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          if (userName.isNotEmpty)
            Text(userName,
                style:
                    TextStyle(color: Colors.grey[400], fontSize: 13)),
          const SizedBox(width: 16),
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, size: 20),
            color: Colors.grey[400],
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
    );
  }
}

// ── Success Banner ────────────────────────────────────────────────────────────

class _SuccessBanner extends StatelessWidget {
  final String message;
  const _SuccessBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      color: const Color(0xFF7C3AED).withOpacity(0.15),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              color: Color(0xFF8B5CF6), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Toolbar ───────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final VoidCallback onPickFiles;
  const _Toolbar({required this.onPickFiles});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<FilesProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb — equivale a <nav> con los crumbs en files.tsx
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < prov.crumbs.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('/',
                        style: TextStyle(color: Colors.grey[600])),
                  ),
                InkWell(
                  onTap: () => prov.navTo(i),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Text(
                      i == 0 ? 'Inicio' : prov.crumbs[i].name,
                      style: TextStyle(
                        color: i == prov.crumbs.length - 1
                            ? Colors.white
                            : Colors.grey[400],
                        fontWeight: i == prov.crumbs.length - 1
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Búsqueda + Botones
        Row(
          children: [
            // Campo de búsqueda
            SizedBox(
              width: 240,
              child: TextField(
                onChanged: prov.setQuery,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  prefixIcon: const Icon(Icons.search,
                      color: Colors.grey, size: 18),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2D2D4A)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2D2D4A)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Botón: Nueva carpeta
            OutlinedButton.icon(
              onPressed: () => _showNewFolderDialog(context),
              icon: const Icon(Icons.create_new_folder_outlined, size: 16),
              label: const Text('Carpeta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF2D2D4A)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(width: 8),

            // Botón: Subir archivos
            ElevatedButton.icon(
              onPressed: prov.uploading ? null : onPickFiles,
              icon: prov.uploading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.upload_outlined, size: 16),
              label: Text(prov.uploading
                  ? 'Subiendo ${(prov.uploadProgress * 100).toStringAsFixed(0)}%'
                  : 'Subir archivos'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showNewFolderDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _NameDialog(controller: ctrl, title: 'Nueva carpeta'),
    );
    if (confirmed == true &&
        ctrl.text.trim().isNotEmpty &&
        context.mounted) {
      await context.read<FilesProvider>().createFolder(ctrl.text.trim());
    }
    ctrl.dispose();
  }
}

// ── Drop Zone ─────────────────────────────────────────────────────────────────

/// Zona de arrastrar y soltar archivos.
/// Equivale a la función DropZone en files.tsx.
class _DropZone extends StatefulWidget {
  final Future<void> Function(List<File>) onFiles;
  const _DropZone({required this.onFiles});

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool _isDragging = false; // Equivale a const [over, setOver] = useState(false)

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<FilesProvider>();

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (detail) {
        setState(() => _isDragging = false);
        final fileList = detail.files
            .map((xf) => File(xf.path))
            .toList();
        widget.onFiles(fileList);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 110,
        decoration: BoxDecoration(
          color: _isDragging
              ? const Color(0xFF7C3AED).withOpacity(0.12)
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isDragging
                ? const Color(0xFF8B5CF6)
                : const Color(0xFF2D2D4A),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(Icons.upload_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(height: 8),
              const Text('Arrastra archivos aquí o haz clic en "Subir archivos"',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(height: 4),
              Text('Cifrado AES-256-GCM · Hasta 2 GB por archivo',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── File Table ────────────────────────────────────────────────────────────────

class _FileTable extends StatelessWidget {
  final void Function(ArchiveDto) onDownload;
  final void Function(ArchiveDto) onCopyLink;
  final void Function(ArchiveDto) onRenameFile;
  final void Function(ArchiveDto) onMoveFile;
  final void Function(ArchiveDto) onDeleteFile;
  final void Function(DirectoryDto) onRenameDir;
  final void Function(DirectoryDto) onDeleteDir;

  const _FileTable({
    required this.onDownload,
    required this.onCopyLink,
    required this.onRenameFile,
    required this.onMoveFile,
    required this.onDeleteFile,
    required this.onRenameDir,
    required this.onDeleteDir,
  });

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<FilesProvider>();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2D2D4A)),
      ),
      child: Column(
        children: [
          // Encabezado de la tabla
          _TableHeader(),

          // Loading
          if (prov.loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
              ),
            )
          // Vacío
          else if (prov.filteredDirs.isEmpty && prov.filteredFiles.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  prov.query.isNotEmpty
                      ? 'Sin resultados para "${prov.query}"'
                      : 'Esta carpeta está vacía.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),
            )
          else ...[
            // Filas de carpetas
            ...prov.filteredDirs.map((d) => _DirRow(
                  dir: d,
                  onOpen: () => prov.openDir(d),
                  onRename: () => onRenameDir(d),
                  onDelete: () => onDeleteDir(d),
                )),
            // Filas de archivos
            ...prov.filteredFiles.map((f) => _FileRow(
                  file: f,
                  onToggleVisibility: () => prov.toggleVisibility(f),
                  onDownload: () => onDownload(f),
                  onCopyLink: () => onCopyLink(f),
                  onRename: () => onRenameFile(f),
                  onMove: () => onMoveFile(f),
                  onDelete: () => onDeleteFile(f),
                )),
          ],
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Color(0xFF2D2D4A))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text('Nombre',
                style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
          ),
          Expanded(
            flex: 2,
            child: Text('Visibilidad',
                style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
          ),
          Expanded(
            flex: 2,
            child: Text('Tipo',
                style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
          ),
          const SizedBox(width: 120, child: Text('')),
        ],
      ),
    );
  }
}

// ── Fila de carpeta ───────────────────────────────────────────────────────────

class _DirRow extends StatelessWidget {
  final DirectoryDto dir;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _DirRow({
    required this.dir,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _TableRow(
      onTap: onOpen,
      nameWidget: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.folder_outlined,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              dir.directoryName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      visibilityWidget: Text('—',
          style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      typeWidget: Text('Carpeta',
          style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      actionsWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconBtn(icon: Icons.drive_file_rename_outline, tooltip: 'Renombrar', onTap: onRename),
          _IconBtn(icon: Icons.delete_outline, tooltip: 'Eliminar', onTap: onDelete),
        ],
      ),
    );
  }
}

// ── Fila de archivo ───────────────────────────────────────────────────────────

class _FileRow extends StatelessWidget {
  final ArchiveDto file;
  final VoidCallback onToggleVisibility;
  final VoidCallback onDownload;
  final VoidCallback onCopyLink;
  final VoidCallback onRename;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  const _FileRow({
    required this.file,
    required this.onToggleVisibility,
    required this.onDownload,
    required this.onCopyLink,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
  });

  IconData _fileIcon(String name) {
    final ext = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';
    if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'].contains(ext)) {
      return Icons.image_outlined;
    }
    if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)) {
      return Icons.movie_outlined;
    }
    if (['mp3', 'wav', 'ogg', 'flac'].contains(ext)) {
      return Icons.music_note_outlined;
    }
    if (['pdf', 'doc', 'docx', 'txt', 'md'].contains(ext)) {
      return Icons.description_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return _TableRow(
      nameWidget: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D4A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_fileIcon(file.archiveName),
                color: const Color(0xFF8B5CF6), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              file.archiveName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      // Chip de visibilidad — equivale al <button> de is_public en files.tsx
      visibilityWidget: GestureDetector(
        onTap: onToggleVisibility,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: file.isPublic
                ? const Color(0xFF7C3AED).withOpacity(0.2)
                : const Color(0xFF2D2D4A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                file.isPublic ? Icons.public : Icons.lock_outline,
                size: 12,
                color: file.isPublic
                    ? const Color(0xFF8B5CF6)
                    : Colors.grey[400],
              ),
              const SizedBox(width: 4),
              Text(
                file.isPublic ? 'Público' : 'Privado',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: file.isPublic
                      ? const Color(0xFF8B5CF6)
                      : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
      typeWidget: Text('Archivo',
          style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      actionsWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconBtn(icon: Icons.download_outlined, tooltip: 'Descargar', onTap: onDownload),
          if (file.isPublic && file.shareToken != null)
            _IconBtn(icon: Icons.link, tooltip: 'Copiar enlace', onTap: onCopyLink),
          _IconBtn(icon: Icons.drive_file_rename_outline, tooltip: 'Renombrar', onTap: onRename),
          _IconBtn(icon: Icons.drive_file_move_outline, tooltip: 'Mover', onTap: onMove),
          _IconBtn(icon: Icons.delete_outline, tooltip: 'Eliminar', onTap: onDelete),
        ],
      ),
    );
  }
}

// ── Fila genérica de la tabla ─────────────────────────────────────────────────

class _TableRow extends StatefulWidget {
  final Widget nameWidget;
  final Widget visibilityWidget;
  final Widget typeWidget;
  final Widget actionsWidget;
  final VoidCallback? onTap;

  const _TableRow({
    required this.nameWidget,
    required this.visibilityWidget,
    required this.typeWidget,
    required this.actionsWidget,
    this.onTap,
  });

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withOpacity(0.03)
                : Colors.transparent,
            border: const Border(
              bottom: BorderSide(color: Color(0xFF2D2D4A), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 5, child: widget.nameWidget),
              Expanded(flex: 2, child: widget.visibilityWidget),
              Expanded(flex: 2, child: widget.typeWidget),
              SizedBox(width: 120, child: widget.actionsWidget),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Botón de ícono pequeño ────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 17, color: Colors.grey[400]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DIÁLOGOS
// ══════════════════════════════════════════════════════════════════════════════

// ── Diálogo: Nombre (crear carpeta / renombrar) ───────────────────────────────
/// Equivale a los estados nameDialog + el <Dialog> de nombre en files.tsx

class _NameDialog extends StatelessWidget {
  final TextEditingController controller;
  final String title;
  const _NameDialog({required this.controller, required this.title});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2D2D4A)),
      ),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 17)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Escribe un nombre…',
          hintStyle: TextStyle(color: Colors.grey),
        ),
        onSubmitted: (_) => Navigator.pop(context, true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(minimumSize: const Size(100, 38)),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

// ── Diálogo: Confirmación de eliminación (3 pasos) ────────────────────────────
/// Equivale al <AlertDialog> con confirmStep 1/2/3 en files.tsx

class _DeleteDialog extends StatefulWidget {
  final String name;
  final bool isDir;
  const _DeleteDialog({required this.name, required this.isDir});

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  // Equivale a confirmStep en React: 1, 2 ó 3
  int _step = 1;

  @override
  Widget build(BuildContext context) {
    final tipo = widget.isDir ? 'carpeta' : 'archivo';

    final titles = [
      '¿Eliminar $tipo?',
      'Segunda confirmación',
      'Confirmación final',
    ];
    final descriptions = [
      'Estás a punto de eliminar "${widget.name}".'
          '${widget.isDir ? ' Se eliminarán todos sus contenidos.' : ''}',
      '¿Estás seguro de eliminar "${widget.name}"?',
      'Esta acción NO se puede deshacer. ¿Confirmas eliminar definitivamente "${widget.name}"?',
    ];

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2D2D4A)),
      ),
      title: Text(titles[_step - 1],
          style: const TextStyle(color: Colors.white, fontSize: 17)),
      content: Text(descriptions[_step - 1],
          style: TextStyle(color: Colors.grey[300], fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_step < 3) {
              setState(() => _step++);
            } else {
              Navigator.pop(context, true);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _step == 3 ? Colors.redAccent : const Color(0xFF7C3AED),
            minimumSize: const Size(120, 38),
          ),
          child: Text(_step == 3 ? 'Eliminar definitivamente' : 'Sí, continuar'),
        ),
      ],
    );
  }
}

// ── Diálogo: Mover archivo ────────────────────────────────────────────────────
/// Equivale al <Dialog> de mover en files.tsx

class _MoveDialog extends StatefulWidget {
  final List<DirectoryDto> allDirs;
  final String? currentDirId;
  const _MoveDialog({required this.allDirs, this.currentDirId});

  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentDirId ?? 'root';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2D2D4A)),
      ),
      title: const Text('Mover archivo',
          style: TextStyle(color: Colors.white, fontSize: 17)),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Destino',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            const SizedBox(height: 8),
            // Lista de opciones de destino
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2D2D4A)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedId,
                  dropdownColor: const Color(0xFF1A1A2E),
                  isExpanded: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  items: [
                    const DropdownMenuItem(
                      value: 'root',
                      child: Text('📁 Raíz (sin carpeta)',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                    ...widget.allDirs.map((d) => DropdownMenuItem(
                          value: d.directoryId,
                          child: Text('📁 ${d.directoryName}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedId = v!),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedId),
          style: ElevatedButton.styleFrom(minimumSize: const Size(80, 38)),
          child: const Text('Mover'),
        ),
      ],
    );
  }
}
