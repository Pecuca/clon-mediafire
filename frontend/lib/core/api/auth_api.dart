// ╔══════════════════════════════════════════════════════════════╗
// ║  api/auth_api.dart — Llamadas de autenticación              ║
// ║                                                              ║
// ║  Equivale a authApi en api.ts:                              ║
// ║    authApi.login(email, password)                            ║
// ║    authApi.register(name, email, password)                   ║
// ║    authApi.logout()                                          ║
// ║    authApi.forgotPassword(email)                             ║
// ╚══════════════════════════════════════════════════════════════╝

import 'api_client.dart';
import '../models/user_dto.dart';

class AuthApi {
  final ApiClient _client;
  const AuthApi(this._client);

  /// POST /auth/register
  Future<UserDto> register(String name, String email, String password) async {
    final res = await _client.request<Map<String, dynamic>>(
      method: 'POST',
      path: '/auth/register',
      data: {'name': name, 'email': email, 'password': password},
    );
    return UserDto.fromJson(res.data!);
  }

  /// POST /auth/login
  Future<UserDto> login(String email, String password) async {
    final res = await _client.request<Map<String, dynamic>>(
      method: 'POST',
      path: '/auth/login',
      data: {'email': email, 'password': password},
    );
    return UserDto.fromJson(res.data!);
  }

  /// POST /auth/logout
  Future<void> logout() async {
    await _client.request<void>(
      method: 'POST',
      path: '/auth/logout',
    );
  }

  /// POST /auth/forget-password
  Future<String> forgotPassword(String email) async {
    final res = await _client.request<Map<String, dynamic>>(
      method: 'POST',
      path: '/auth/forget-password',
      data: {'email': email},
    );
    return res.data?['message'] as String? ?? 'Correo enviado';
  }
}
