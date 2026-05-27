// ╔══════════════════════════════════════════════════════════════╗
// ║  models/archive_dto.dart                                     ║
// ║                                                              ║
// ║  Equivalente a ArchiveDto en api.ts:                        ║
// ║    interface ArchiveDto {                                     ║
// ║      archive_id: string; archive_na: string;                 ║
// ║      hash: string; is_public: boolean; ...                  ║
// ║    }                                                          ║
// ╚══════════════════════════════════════════════════════════════╝

class ArchiveDto {
  final String archiveId;
  final String archiveName;
  final String hash;
  final bool isPublic;
  final String userId;
  final String? directoryId;
  final String? shareToken;

  const ArchiveDto({
    required this.archiveId,
    required this.archiveName,
    required this.hash,
    required this.isPublic,
    required this.userId,
    this.directoryId,
    this.shareToken,
  });

  factory ArchiveDto.fromJson(Map<String, dynamic> json) {
    return ArchiveDto(
      archiveId: json['archive_id'] as String,
      archiveName: json['archive_na'] as String,
      hash: json['hash'] as String? ?? '',
      isPublic: json['is_public'] as bool? ?? false,
      userId: json['user_id'] as String,
      directoryId: json['directory_id'] as String?,
      shareToken: json['share_token'] as String?,
    );
  }

  ArchiveDto copyWith({bool? isPublic, String? archiveName}) {
    return ArchiveDto(
      archiveId: archiveId,
      archiveName: archiveName ?? this.archiveName,
      hash: hash,
      isPublic: isPublic ?? this.isPublic,
      userId: userId,
      directoryId: directoryId,
      shareToken: shareToken,
    );
  }
}
