import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';

/// Reset Password Screen
///
/// Features:
/// - Deep link handler for reset token
/// - New password input with validation rules:
///   - Min 8 characters
///   - At least 1 uppercase
///   - At least 1 number
///   - At least 1 special character
/// - Confirm password field with match validation
/// - Password strength indicator
/// - Submit button
/// - Success confirmation with auto-redirect to login
class ResetPasswordScreen extends StatefulWidget {
  final String? token;

  const ResetPasswordScreen({
    super.key,
    this.token,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _resetSuccess = false;
  String? _errorMessage;
  PasswordStrength _passwordStrength = PasswordStrength.weak;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await supabaseAuth.updateUser(
        UserAttributes(
          password: _passwordController.text,
        ),
      );

      if (mounted) {
        setState(() {
          _resetSuccess = true;
          _isLoading = false;
        });

        // Auto-redirect to login after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            context.go('/');
          }
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Er is een fout opgetreden. Probeer het opnieuw.';
        _isLoading = false;
      });
    }
  }

  void _checkPasswordStrength(String password) {
    setState(() {
      _passwordStrength = _calculatePasswordStrength(password);
    });
  }

  PasswordStrength _calculatePasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.weak;

    int score = 0;

    // Length check
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;

    // Character variety
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Wachtwoord is verplicht';
    }

    if (value.length < 8) {
      return 'Minimaal 8 tekens';
    }

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Minimaal 1 hoofdletter';
    }

    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Minimaal 1 cijfer';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Minimaal 1 speciaal teken';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nieuw wachtwoord'),
        elevation: 0,
        automaticallyImplyLeading: !_resetSuccess,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _resetSuccess ? _buildSuccessView(theme) : _buildFormView(theme),
        ),
      ),
    );
  }

  Widget _buildFormView(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),

          // Icon
          Icon(
            Icons.lock_reset,
            size: 80,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            'Kies een nieuw wachtwoord',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            'Maak een sterk wachtwoord dat je nog niet eerder hebt gebruikt.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),

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

          // New password field
          TextFormField(
            controller: _passwordController,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: 'Nieuw wachtwoord',
              hintText: 'Minimaal 8 tekens',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() => _showPassword = !_showPassword);
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textInputAction: TextInputAction.next,
            enabled: !_isLoading,
            onChanged: _checkPasswordStrength,
            validator: _validatePassword,
          ),
          const SizedBox(height: 16),

          // Password strength indicator
          _buildPasswordStrengthIndicator(theme),
          const SizedBox(height: 16),

          // Confirm password field
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_showConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Bevestig wachtwoord',
              hintText: 'Herhaal je wachtwoord',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() => _showConfirmPassword = !_showConfirmPassword);
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textInputAction: TextInputAction.done,
            enabled: !_isLoading,
            onFieldSubmitted: (_) => _resetPassword(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Bevestig je wachtwoord';
              }

              if (value != _passwordController.text) {
                return 'Wachtwoorden komen niet overeen';
              }

              return null;
            },
          ),
          const SizedBox(height: 24),

          // Requirements list
          _buildRequirementsList(theme),
          const SizedBox(height: 24),

          // Reset password button
          FilledButton.icon(
            onPressed: _isLoading ? null : _resetPassword,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(_isLoading ? 'Opslaan...' : 'Wachtwoord opslaan'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator(ThemeData theme) {
    Color strengthColor;
    String strengthText;
    double strengthValue;

    switch (_passwordStrength) {
      case PasswordStrength.weak:
        strengthColor = Colors.red;
        strengthText = 'Zwak';
        strengthValue = 0.33;
        break;
      case PasswordStrength.medium:
        strengthColor = Colors.orange;
        strengthText = 'Gemiddeld';
        strengthValue = 0.66;
        break;
      case PasswordStrength.strong:
        strengthColor = Colors.green;
        strengthText = 'Sterk';
        strengthValue = 1.0;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Wachtwoord sterkte:',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              strengthText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: strengthColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: strengthValue,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(strengthColor),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementsList(ThemeData theme) {
    final password = _passwordController.text;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wachtwoord vereisten:',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildRequirementItem(
            theme,
            'Minimaal 8 tekens',
            password.length >= 8,
          ),
          _buildRequirementItem(
            theme,
            'Minimaal 1 hoofdletter',
            RegExp(r'[A-Z]').hasMatch(password),
          ),
          _buildRequirementItem(
            theme,
            'Minimaal 1 cijfer',
            RegExp(r'[0-9]').hasMatch(password),
          ),
          _buildRequirementItem(
            theme,
            'Minimaal 1 speciaal teken (!@#\$%^&*)',
            RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(ThemeData theme, String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 20,
            color: isMet ? Colors.green : theme.colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isMet ? Colors.green : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 48),

        // Success icon
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            size: 80,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 32),

        // Success title
        Text(
          'Wachtwoord gewijzigd!',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 16),

        // Success message
        Text(
          'Je wachtwoord is succesvol gewijzigd. Je wordt automatisch doorgestuurd naar het inlogscherm.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),

        // Loading indicator
        const Center(
          child: CircularProgressIndicator(),
        ),
        const SizedBox(height: 16),
        Text(
          'Doorsturen...',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),

        // Manual navigation button
        OutlinedButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Ga nu naar inloggen'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }
}

enum PasswordStrength {
  weak,
  medium,
  strong,
}
