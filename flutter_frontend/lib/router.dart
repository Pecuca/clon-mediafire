// ╔══════════════════════════════════════════════════════════════╗
// ║  router.dart — Navegación de la app                         ║
// ║                                                              ║
// ║  GoRouter es el equivalente a TanStack Router en React.     ║
// ║  Define qué pantalla mostrar para cada "ruta" (URL/path).  ║
// ║                                                              ║
// ║  En React:                                                   ║
// ║    createFileRoute('/login')({ component: LoginPage })       ║
// ║  En Flutter:                                                 ║
// ║    GoRoute(path: '/login', builder: (_, __) => LoginScreen())║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/providers/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/files/files_screen.dart';

/// buildRouter recibe el AuthProvider para poder hacer redirección automática.
/// Si el usuario NO está logueado y trata de ir a /files, lo manda a /login.
/// Si YA está logueado y va a /login, lo manda a /files.
GoRouter buildRouter(AuthProvider auth) {
  return GoRouter(
    // Ruta inicial al abrir la app
    initialLocation: '/login',

    // redirect se ejecuta ANTES de mostrar cualquier pantalla.
    // Equivale al guard de navegación en TanStack Router.
    redirect: (context, state) {
      final loggedIn = auth.user != null;
      final goingToAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

      // No logueado intentando ir a pantalla protegida → manda a login
      if (!loggedIn && !goingToAuth) return '/login';
      // Ya logueado intentando ir a login/register → manda a files
      if (loggedIn && goingToAuth) return '/files';
      return null; // Sin redirección
    },

    // refreshListenable le dice al router que se recalcule cuando
    // el AuthProvider notifique cambios (login / logout).
    refreshListenable: auth,

    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/files',
        builder: (context, state) => const FilesScreen(),
      ),
      // Ruta raíz redirige a login
      GoRoute(
        path: '/',
        redirect: (_, __) => '/login',
      ),
    ],
  );
}
