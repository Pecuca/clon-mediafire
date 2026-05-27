// ╔══════════════════════════════════════════════════════════════╗
// ║  providers/auth_provider.dart — Estado de autenticación     ║
// ║                                                              ║
// ║  En React, el usuario logueado se guardaba en              ║
// ║  sessionStorage: sessionStorage.setItem('user', ...)        ║
// ║                                                              ║
// ║  En Flutter usamos un ChangeNotifier (Provider).            ║
// ║  ChangeNotifier = objeto que avisa a los widgets cuando      ║
// ║  algo cambia, igual que setState() en React.                ║
// ║                                                              ║
// ║  Cuando llamamos notifyListeners(), todos los widgets que   ║
// ║  escuchan este provider se reconstruyen con los nuevos datos.║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../models/user_dto.dart';

class AuthProvider extends ChangeNotifier {
  final AuthApi _authApi;

  // El usuario logueado (null = no autenticado)
  // Equivale a sessionStorage.getItem('user') en React
  UserDto? _user;
  UserDto? get user => _user;

  // Estado de carga y errores (como useState en React)
  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  AuthProvider(ApiClient client) : _authApi = AuthApi(client);

  // ── Login ────────────────────────────────────────────────────────────────

  /// Equivale a onSubmit() en login.tsx.
  /// Si tiene éxito, guarda el usuario y notifica al router
  /// para que redirija a /files.
  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners(); // Redibujar para mostrar el spinner

    try {
      _user = await _authApi.login(email, password);
      notifyListeners(); // El router detectará que user != null → redirige a /files
      return true;
    } on ApiError catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Register ─────────────────────────────────────────────────────────────

  /// Equivale a onSubmit() en register.tsx.
  Future<bool> register(String name, String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // Registrar
      await _authApi.register(name, email, password);
      // Auto-login después del registro (igual que en React)
      _user = await _authApi.login(email, password);
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  /// Equivale a logout() en files.tsx.
  Future<void> logout() async {
    try {
      await _authApi.logout();
    } catch (_) {}
    _user = null;
    notifyListeners(); // El router detectará user == null → redirige a /login
  }

  // ── Forgot Password ───────────────────────────────────────────────────────

  Future<({bool success, String message})> forgotPassword(String email) async {
    _loading = true;
    notifyListeners();
    try {
      final msg = await _authApi.forgotPassword(email);
      return (success: true, message: msg);
    } on ApiError catch (e) {
      return (success: false, message: e.message);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Limpia el error (para cuando el usuario empieza a escribir de nuevo)
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
