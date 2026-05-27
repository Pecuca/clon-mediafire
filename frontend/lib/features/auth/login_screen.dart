// ╔══════════════════════════════════════════════════════════════╗
// ║  features/auth/login_screen.dart                             ║
// ║                                                              ║
// ║  Equivale a login.tsx.                                       ║
// ║                                                              ║
// ║  En React:                                                   ║
// ║    const [email, setEmail] = useState('')                    ║
// ║    const [loading, setLoading] = useState(false)             ║
// ║                                                              ║
// ║  En Flutter (StatefulWidget):                                ║
// ║    String _email = '';                                        ║
// ║    // loading viene de AuthProvider                          ║
// ║                                                              ║
// ║  StatefulWidget = componente que tiene estado interno        ║
// ║  (campos de formulario, controladores de texto, etc.).       ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../shared/auth_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// _LoginScreenState es la clase que guarda el estado del widget.
/// Es el equivalente a las variables de estado (useState) en React.
class _LoginScreenState extends State<LoginScreen> {
  // TextEditingController = equivale a useState('') para inputs en Flutter.
  // Permite leer y escribir el valor del campo de texto.
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // _formKey permite validar el formulario (requeridos, formato de email, etc.)
  final _formKey = GlobalKey<FormState>();

  // Controla si la contraseña se muestra o se oculta
  bool _obscurePassword = true;

  @override
  void dispose() {
    // Importante: liberar los controladores cuando el widget se destruye.
    // Equivale al cleanup de useEffect en React.
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// onSubmit — equivale a async function onSubmit(e: FormEvent) en login.tsx
  Future<void> _onSubmit() async {
    // Validar el formulario antes de enviar
    if (!_formKey.currentState!.validate()) return;

    // context.read<AuthProvider>() obtiene el AuthProvider sin escucharlo.
    // Equivale a llamar directamente a authApi.login() en React.
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_emailCtrl.text.trim(), _passwordCtrl.text);

    // Si el login fue exitoso, el router automáticamente redirige a /files
    // gracias al refreshListenable configurado en router.dart.
    // No necesitamos hacer navigate manualmente.
    if (!ok && mounted) {
      // Si falló, el error ya está en auth.error y se muestra en el build.
    }
  }

  @override
  Widget build(BuildContext context) {
    // context.watch<AuthProvider>() sí escucha cambios.
    // Cuando loading cambia, este widget se reconstruye (como useState en React).
    final auth = context.watch<AuthProvider>();

    return AuthLayout(
      title: 'Bienvenido de vuelta',
      subtitle: 'Inicia sesión para acceder a tus archivos.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('¿Aún no tienes cuenta? ',
              style: TextStyle(color: Colors.grey[400])),
          TextButton(
            onPressed: () => context.push('/register'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Regístrate'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Campo: correo electrónico
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                hintText: 'tu@correo.com',
                prefixIcon: Icon(Icons.email_outlined, color: Colors.grey),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa tu correo';
                if (!v.contains('@')) return 'Correo inválido';
                return null;
              },
              onFieldSubmitted: (_) => _onSubmit(),
            ),
            const SizedBox(height: 16),

            // Campo: contraseña
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
              onFieldSubmitted: (_) => _onSubmit(),
            ),

            // Enlace: ¿Olvidaste tu contraseña?
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/forgot-password'),
                child: const Text('¿Olvidaste tu contraseña?',
                    style: TextStyle(fontSize: 12)),
              ),
            ),

            // Mensaje de error (equivale al <p className="text-destructive"> en React)
            if (auth.error != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  auth.error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 8),

            // Botón de submit
            // Equivale a <Button disabled={loading}> en React
            ElevatedButton(
              onPressed: auth.loading ? null : _onSubmit,
              child: auth.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
