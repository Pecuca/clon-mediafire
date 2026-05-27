// ╔══════════════════════════════════════════════════════════════╗
// ║  main.dart — Punto de entrada de ColapsoLoad                ║
// ║                                                              ║
// ║  En Flutter, main() es la función que arranca todo,         ║
// ║  igual que index.tsx en React.                              ║
// ║                                                              ║
// ║  MaterialApp.router le dice a Flutter que usamos GoRouter   ║
// ║  para manejar la navegación entre pantallas.                ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/api/api_client.dart';
import 'router.dart';

void main() {
  // Asegura que los bindings de Flutter estén listos antes de
  // cualquier operación nativa (archivos, ventanas, etc.)
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ColapsoLoadApp());
}

class ColapsoLoadApp extends StatelessWidget {
  const ColapsoLoadApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider es el equivalente a tener múltiples Context en React.
    // Aquí registramos los "providers" (estado global) disponibles en toda la app.
    return MultiProvider(
      providers: [
        // ApiClient es el cliente HTTP con cookies de sesión.
        // Lo creamos una sola vez aquí y lo compartimos en toda la app.
        Provider<ApiClient>(
          create: (_) => ApiClient(),
          dispose: (_, client) => client.dispose(),
        ),
        // AuthProvider guarda al usuario logueado (equivale a sessionStorage en React).
        // ChangeNotifierProxyProvider "depende" del ApiClient ya creado arriba.
        ChangeNotifierProxyProvider<ApiClient, AuthProvider>(
          create: (ctx) => AuthProvider(ctx.read<ApiClient>()),
          update: (ctx, api, prev) => prev ?? AuthProvider(api),
        ),
      ],
      // Consumer<AuthProvider> re-construye el MaterialApp cuando el usuario
      // inicia o cierra sesión, actualizando las rutas disponibles.
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp.router(
            title: 'ColapsoLoad',
            debugShowCheckedModeBanner: false,
            // AppTheme.dark() devuelve nuestro tema oscuro personalizado
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            // routerConfig conecta GoRouter con Flutter
            routerConfig: buildRouter(auth),
          );
        },
      ),
    );
  }
}

// ── Tema de la app ────────────────────────────────────────────────────────────
// Equivalente a styles.css en el proyecto React.
// Define colores, tipografía y estilos globales.
class AppTheme {
  // Color principal de la marca (morado/azul)
  static const _brandColor = Color(0xFF7C3AED); // violet-600
  static const _brandLight = Color(0xFF8B5CF6); // violet-500
  static const _surface = Color(0xFF0F0F1A);    // fondo oscuro
  static const _card = Color(0xFF1A1A2E);        // tarjetas
  static const _cardBorder = Color(0xFF2D2D4A);  // bordes

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: _brandLight,
        secondary: _brandColor,
        surface: _surface,
        surfaceContainerHighest: _card,
        outline: _cardBorder,
        onSurface: Colors.white,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: _surface,
      cardColor: _card,
      fontFamily: 'Inter',
      // Estilo de los TextFields (campos de texto)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _brandLight, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        hintStyle: const TextStyle(color: Color(0xFF6B7280)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      // Estilo de los botones elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _brandLight),
      ),
    );
  }

  static ThemeData light() => dark(); // Solo modo oscuro por ahora
}
