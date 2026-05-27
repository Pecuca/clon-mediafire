// ╔══════════════════════════════════════════════════════════════╗
// ║  api/api_client.dart — Cliente HTTP con manejo de sesión     ║
// ║                                                              ║
// ║  En React: fetch(..., { credentials: 'include' })           ║
// ║  envía las cookies automáticamente porque el NAVEGADOR       ║
// ║  las guarda.                                                 ║
// ║                                                              ║
// ║  En Flutter (app nativa) NO hay navegador, así que          ║
// ║  debemos guardar las cookies manualmente con CookieJar       ║
// ║  y adjuntarlas a cada request con Dio.                      ║
// ║                                                              ║
// ║  Dio es una librería HTTP más potente que http básico,       ║
// ║  similar a axios en el mundo JavaScript.                    ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

/// ApiError es nuestra excepción personalizada.
/// Equivale a la clase ApiError en api.ts.
class ApiError implements Exception {
  final String message;
  final int status;
  const ApiError(this.message, this.status);

  @override
  String toString() => 'ApiError($status): $message';
}

/// ApiClient es el "corazón" de todas las llamadas HTTP.
/// Se crea UNA SOLA VEZ en main.dart y se comparte con Provider.
class ApiClient {
  // URL base del backend NestJS (igual que API_BASE en api.ts)
  static const String baseUrl = 'http://localhost:3000';

  // Dio es nuestra instancia del cliente HTTP
  late final Dio _dio;

  // CookieJar guarda en memoria las cookies de sesión que el servidor envía.
  // Cuando el backend hace Set-Cookie: connect.sid=..., CookieJar lo almacena
  // y lo incluye automáticamente en cada request posterior.
  final _cookieJar = CookieJar();

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      // Importante: le decimos a Dio que no lance excepción en errores HTTP.
      // Nosotros mismos revisamos el status code para dar mensajes claros.
      validateStatus: (_) => true,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // CookieManager intercepta cada request/response para manejar cookies.
    // Equivale a credentials: 'include' en fetch().
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  /// request<T> es el método genérico que todas las APIs usan.
  /// Equivale a la función request<T>() en api.ts.
  ///
  /// T es el tipo de retorno esperado (p.ej. Map<String, dynamic> para JSON).
  Future<Response<T>> request<T>({
    required String method,
    required String path,
    dynamic data,
    Map<String, String>? headers,
    ResponseType? responseType,
    void Function(int, int)? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.request<T>(
        path,
        data: data,
        options: Options(
          method: method,
          headers: headers,
          responseType: responseType ?? ResponseType.json,
          receiveDataWhenStatusError: true,
        ),
        onReceiveProgress: onReceiveProgress,
      );

      // Si el status NO es exitoso (200-299), lanzamos ApiError
      if (response.statusCode == null || response.statusCode! >= 400) {
        String msg = 'Error ${response.statusCode}';
        // Intentar extraer el mensaje del cuerpo JSON del error
        if (response.data is Map) {
          final body = response.data as Map;
          msg = body['message']?.toString() ?? msg;
        }
        throw ApiError(msg, response.statusCode ?? 500);
      }

      return response;
    } on DioException catch (e) {
      // DioException ocurre cuando hay problemas de red (sin conexión, timeout, etc.)
      throw ApiError(
        e.message ?? 'Error de red',
        e.response?.statusCode ?? 0,
      );
    }
  }

  /// Acceso directo al cliente Dio para operaciones especiales (upload multipart)
  Dio get dio => _dio;

  void dispose() {
    _dio.close();
  }
}
