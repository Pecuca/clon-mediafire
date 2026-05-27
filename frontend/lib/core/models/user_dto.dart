// ╔══════════════════════════════════════════════════════════════╗
// ║  models/user_dto.dart                                        ║
// ║                                                              ║
// ║  Equivalente a la interfaz UserDto en api.ts:               ║
// ║    interface UserDto {                                        ║
// ║      user_id: string; user_na: string; user_mail: string;   ║
// ║    }                                                          ║
// ║                                                              ║
// ║  En Dart usamos una clase con factory fromJson para          ║
// ║  convertir la respuesta JSON del backend a un objeto Dart.   ║
// ╚══════════════════════════════════════════════════════════════╝

class UserDto {
  final String userId;
  final String userName;
  final String userMail;
  final String? publicKey;

  const UserDto({
    required this.userId,
    required this.userName,
    required this.userMail,
    this.publicKey,
  });

  /// factory fromJson: convierte un Map<String, dynamic> (JSON del backend)
  /// a un objeto UserDto. Equivale a JSON.parse() en JavaScript.
  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      userId: json['user_id'].toString(),
      userName: json['user_na'] as String,
      userMail: json['user_mail'] as String,
      publicKey: json['public_key'] as String?,
    );
  }
}
