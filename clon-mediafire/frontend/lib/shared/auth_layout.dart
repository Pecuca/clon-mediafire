// ╔══════════════════════════════════════════════════════════════╗
// ║  shared/auth_layout.dart                                     ║
// ║                                                              ║
// ║  Equivale a AuthLayout.tsx — el layout de dos columnas      ║
// ║  que usan login, register y forgot-password.                ║
// ║                                                              ║
// ║  En React era un componente funcional con props:             ║
// ║    <AuthLayout title="..." subtitle="..." footer={...}>      ║
// ║      {children}                                              ║
// ║    </AuthLayout>                                             ║
// ║                                                              ║
// ║  En Flutter es un StatelessWidget con parámetros            ║
// ║  equivalentes. La columna izquierda es decorativa            ║
// ║  (morada con texto de marketing), la derecha tiene          ║
// ║  el formulario.                                              ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';

class AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;       // El formulario (equivale a {children})
  final Widget? footer;     // Enlace de "¿Ya tienes cuenta?"

  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          margin: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Columna izquierda: decorativa (solo en pantallas anchas) ──
                // Equivale al <aside> en AuthLayout.tsx
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.cloud_upload_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'ColapsoLoad',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Slogan
                        const Text(
                          'Tus archivos, en un solo lugar seguro.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sube, organiza y comparte. Cifrado AES-256-GCM de extremo a extremo.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Chips de características
                        _FeatureChip(Icons.lock_outline, 'AES-256-GCM'),
                        const SizedBox(height: 8),
                        _FeatureChip(Icons.vpn_key_outlined, 'RSA-OAEP'),
                        const SizedBox(height: 8),
                        _FeatureChip(Icons.verified_outlined, 'Verificación SHA-256'),
                      ],
                    ),
                  ),
                ),
                // ── Columna derecha: formulario ──────────────────────────────
                // Equivale al <section> en AuthLayout.tsx
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        // Título de la pantalla
                        Text(
                          title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // El formulario en sí (login form, register form, etc.)
                        child,
                        // Footer (enlace a register/login)
                        if (footer != null) ...[
                          const SizedBox(height: 24),
                          DefaultTextStyle(
                            style: TextStyle(color: Colors.grey[400], fontSize: 13),
                            child: footer!,
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip pequeño para mostrar las características de seguridad en la columna izquierda
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.7), size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
