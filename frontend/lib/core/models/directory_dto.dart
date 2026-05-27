// ╔══════════════════════════════════════════════════════════════╗
// ║  models/directory_dto.dart                                   ║
// ║                                                              ║
// ║  Equivalente a DirectoryDto en api.ts:                      ║
// ║    interface DirectoryDto {                                   ║
// ║      directory_id: string;                                   ║
// ║      directory_name: string;                                 ║
// ║      user_id: string;                                        ║
// ║    }                                                          ║
// ╚══════════════════════════════════════════════════════════════╝

class DirectoryDto {
  final String directoryId;
  final String directoryName;
  final String userId;

  const DirectoryDto({
    required this.directoryId,
    required this.directoryName,
    required this.userId,
  });

  factory DirectoryDto.fromJson(Map<String, dynamic> json) {
    return DirectoryDto(
      directoryId: json['directory_id']?.toString() ?? '',
      directoryName: json['directory_name']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
    );
  }

  /// copyWith permite crear una copia con un campo modificado.
  /// Útil para renombrar: dir.copyWith(directoryName: 'nuevo nombre')
  DirectoryDto copyWith({String? directoryName}) {
    return DirectoryDto(
      directoryId: directoryId,
      directoryName: directoryName ?? this.directoryName,
      userId: userId,
    );
  }
}
