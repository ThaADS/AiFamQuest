import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../api/client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'parent@example.com');
  final _password = TextEditingController(text: 'secret123');
  final _otp = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.login(
        _email.text,
        _password.text,
        otp: _otp.text.isEmpty ? null : _otp.text,
      );

      if (!mounted) return;

      // Check if 2FA is required
      if (response['requires2FA'] == true) {
        context.push('/2fa/verify', extra: {
          'email': _email.text,
          'password': _password.text,
        });
      } else {
        context.go('/home');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Send to backend for verification
      final response = await ApiClient.instance.appleSignIn(
        authorizationCode: credential.authorizationCode,
        identityToken: credential.identityToken ?? '',
        userIdentifier: credential.userIdentifier ?? '',
        email: credential.email ?? '',
        givenName: credential.givenName,
        familyName: credential.familyName,
      );

      if (!mounted) return;

      // Check if 2FA is required
      if (response['requires2FA'] == true) {
        context.push('/2fa/verify', extra: {
          'email': response['email'],
          'isApple': true,
        });
      } else {
        context.go('/home');
      }
    } catch (e) {
      setState(() => _error = 'Apple Sign-In failed: ${e.toString()}');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIOS = Platform.isIOS;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inloggen'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App logo/title
              Icon(
                Icons.family_restroom,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'FamQuest',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 48),

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
              ),
              const SizedBox(height: 24),

              // Login button
              FilledButton(
                onPressed: _busy ? null : _handleEmailLogin,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Log in', style: TextStyle(fontSize: 16)),
              ),

              // Error message
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],

              // Divider
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OF'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),

              // Apple Sign-In (iOS only)
              if (isIOS) ...[
                SignInWithAppleButton(
                  onPressed: _busy ? () {} : _handleAppleSignIn,
                  style: SignInWithAppleButtonStyle.black,
                  height: 50,
                ),
                const SizedBox(height: 16),
              ],

              // Demo Mode Button (bypasses backend)
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () {
                        // Direct login without backend for testing
                        context.go('/home');
                      },
                icon: const Icon(Icons.science),
                label: const Text('Demo Mode (Offline Test)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: theme.colorScheme.secondary,
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'Demo mode: Test de app zonder backend server',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
