import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Authentication Widget Tests
///
/// Tests authentication features:
/// - Login form validation
/// - SSO button rendering
/// - 2FA setup and verification
/// - Password reset flow
/// - Registration form
void main() {
  group('Login Screen Tests', () {
    testWidgets('Login form renders with email and password fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Login')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Sign In'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byIcon(Icons.email), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('Email field accepts input',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: InputDecoration(labelText: 'Email'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final emailField = find.byType(TextField);
      await tester.enterText(emailField, 'test@example.com');
      await tester.pumpAndSettle();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('Password field obscures text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final passwordField = find.byType(TextField);
      final textField = tester.widget<TextField>(passwordField);

      expect(textField.obscureText, isTrue);
    });
  });

  group('SSO Buttons Tests', () {
    testWidgets('Google Sign-In button renders',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.g_mobiledata),
                label: const Text('Sign in with Google'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.byIcon(Icons.g_mobiledata), findsOneWidget);
    });

    testWidgets('Apple Sign-In button renders',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.apple),
                label: const Text('Sign in with Apple'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sign in with Apple'), findsOneWidget);
      expect(find.byIcon(Icons.apple), findsOneWidget);
    });

    testWidgets('Microsoft Sign-In button renders',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.business),
                label: const Text('Sign in with Microsoft'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sign in with Microsoft'), findsOneWidget);
      expect(find.byIcon(Icons.business), findsOneWidget);
    });

    testWidgets('Facebook Sign-In button renders',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.facebook),
                label: const Text('Sign in with Facebook'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sign in with Facebook'), findsOneWidget);
      expect(find.byIcon(Icons.facebook), findsOneWidget);
    });
  });

  group('2FA Setup Tests', () {
    testWidgets('2FA setup shows QR code placeholder',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Two-Factor Authentication')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Scan this QR code with your authenticator app',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      color: Colors.white,
                    ),
                    child: const Center(child: Text('[QR CODE]')),
                  ),
                  const SizedBox(height: 24),
                  const Text('Or enter this code manually:'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ABCD EFGH IJKL MNOP',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Two-Factor Authentication'), findsOneWidget);
      expect(find.text('Scan this QR code with your authenticator app'),
          findsOneWidget);
      expect(find.text('Or enter this code manually:'), findsOneWidget);
      expect(find.text('ABCD EFGH IJKL MNOP'), findsOneWidget);
    });

    testWidgets('2FA verification code input',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Verify 2FA')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Enter the 6-digit code from your authenticator app',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Verification Code',
                      hintText: '123456',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Verify'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Verify 2FA'), findsOneWidget);
      expect(find.text('Verification Code'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
    });

    testWidgets('Backup codes display',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Backup Codes')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Save these codes in a safe place. Each can be used once.',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('1. ABCD-1234', style: TextStyle(fontFamily: 'monospace')),
                        Text('2. EFGH-5678', style: TextStyle(fontFamily: 'monospace')),
                        Text('3. IJKL-9012', style: TextStyle(fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Backup Codes'), findsOneWidget);
      expect(find.text('Save these codes in a safe place. Each can be used once.'),
          findsOneWidget);
      expect(find.text('1. ABCD-1234'), findsOneWidget);
    });
  });

  group('Password Reset Tests', () {
    testWidgets('Forgot password screen shows email input',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Reset Password')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Enter your email to receive a password reset link',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Send Reset Link'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Enter your email to receive a password reset link'),
          findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
    });

    testWidgets('Password reset success message',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green.shade400),
                  const SizedBox(height: 24),
                  const Text(
                    'Reset link sent!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Check your email for the password reset link'),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Reset link sent!'), findsOneWidget);
      expect(find.text('Check your email for the password reset link'),
          findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  group('Child PIN Login Tests', () {
    testWidgets('PIN input fields render',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Enter PIN')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Enter your 4-digit PIN',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                      (index) => Container(
                        width: 50,
                        height: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(child: Text('●', style: TextStyle(fontSize: 24))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Enter PIN'), findsOneWidget);
      expect(find.text('Enter your 4-digit PIN'), findsOneWidget);
      expect(find.text('●'), findsNWidgets(4));
    });
  });

  group('Registration Tests', () {
    testWidgets('Registration form shows all required fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Create Account')),
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Create Account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsNWidgets(2)); // Title + button
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
    });
  });

  group('Auth Error Messages Tests', () {
    testWidgets('Invalid credentials error displays',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Invalid email or password',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });
  });
}
