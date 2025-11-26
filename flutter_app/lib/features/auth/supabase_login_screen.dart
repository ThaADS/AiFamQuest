import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import '../../core/app_logger.dart';

class SupabaseLoginScreen extends StatefulWidget {
  const SupabaseLoginScreen({super.key});
  @override
  State<SupabaseLoginScreen> createState() => _SupabaseLoginScreenState();
}

class _SupabaseLoginScreenState extends State<SupabaseLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    AppLogger.debug('[LOGIN] 📧 Starting email login...');
    AppLogger.debug('[LOGIN] Email: ${_email.text}');

    if (_email.text.isEmpty || _password.text.isEmpty) {
      AppLogger.debug('[LOGIN] ❌ Validation failed: empty fields');
      setState(() {
        _errorMessage = 'Vul e-mail en wachtwoord in';
      });
      return;
    }

    AppLogger.debug('[LOGIN] 🔄 Setting busy state...');
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      AppLogger.debug('[LOGIN] 🔐 Calling Supabase signInWithPassword...');
      final response = await supabaseAuth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      AppLogger.debug('[LOGIN] ✅ Login successful!');
      AppLogger.debug('[LOGIN] User ID: ${response.user?.id}');
      AppLogger.debug('[LOGIN] Session: ${response.session != null ? "Present" : "Missing"}');

      if (mounted) {
        AppLogger.debug('[LOGIN] 🏠 Navigating to /home...');
        context.go('/home');
      }
    } on AuthException catch (e) {
      AppLogger.debug('[LOGIN] ❌ AuthException: ${e.message}');
      AppLogger.debug('[LOGIN] Status code: ${e.statusCode}');
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e, stackTrace) {
      AppLogger.debug('[LOGIN] ❌ Generic error: $e');
      AppLogger.debug('[LOGIN] Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Login mislukt: $e';
      });
    } finally {
      AppLogger.debug('[LOGIN] 🏁 Login attempt finished');
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      await supabaseAuth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.famquest://login-callback',
      );

      // Navigation happens automatically via deep link callback
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Google login mislukt: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _handleAppleLogin() async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      await supabaseAuth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'io.supabase.famquest://login-callback',
      );

      // Navigation happens automatically via deep link callback
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Apple login mislukt: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIOS = !kIsWeb && Platform.isIOS;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),

              // Logo + Title
              Icon(
                Icons.family_restroom,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'AiFamQuest',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Maak huishoudelijke taken leuk!',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Email/Password login
              TextField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !_busy,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Wachtwoord',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleEmailLogin(),
                enabled: !_busy,
              ),
              const SizedBox(height: 24),

              // Email Login Button
              ElevatedButton(
                onPressed: _busy ? null : _handleEmailLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Inloggen'),
              ),

              const SizedBox(height: 16),

              // Forgot Password Link
              TextButton(
                onPressed: _busy ? null : () => context.push('/auth/forgot-password'),
                child: const Text('Wachtwoord vergeten?'),
              ),

              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OF'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 32),

              // Google Sign-In
              OutlinedButton.icon(
                onPressed: _busy ? null : _handleGoogleLogin,
                icon: const Icon(Icons.g_mobiledata, size: 32),
                label: const Text('Doorgaan met Google'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 16),

              // Apple Sign-In (iOS only)
              if (isIOS) ...[
                OutlinedButton.icon(
                  onPressed: _busy ? null : _handleAppleLogin,
                  icon: const Icon(Icons.apple, size: 32),
                  label: const Text('Doorgaan met Apple'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Sign up link
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Registreren'),
                            content: const Text(
                              'Ga naar de Supabase dashboard om nieuwe gebruikers aan te maken, '
                              'of gebruik Google/Apple Sign-In.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                child: const Text('Nog geen account? Registreren'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
