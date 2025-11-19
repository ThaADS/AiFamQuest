import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import '../../models/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../core/app_logger.dart';

/// User Profile Settings Screen
///
/// Features:
/// - Display name editor
/// - Theme selector with 6 themes (cartoony/space/stylish/minimal/classy/dark)
/// - Language picker (NL/EN/DE/FR/TR/PL/AR)
/// - Avatar selector
/// - Save button with validation
/// - Real-time theme preview
class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String selectedThemeId = 'cartoony';
  String selectedLanguage = 'nl';
  String selectedAvatar = 'default';

  bool isLoading = true;
  bool isSaving = false;
  bool isChangingPassword = false;
  bool showCurrentPassword = false;
  bool showNewPassword = false;
  bool showConfirmPassword = false;

  // Available languages
  final List<Map<String, dynamic>> languages = [
    {'id': 'nl', 'name': 'Nederlands', 'flag': '🇳🇱'},
    {'id': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'id': 'de', 'name': 'Deutsch', 'flag': '🇩🇪'},
    {'id': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    {'id': 'tr', 'name': 'Türkçe', 'flag': '🇹🇷'},
    {'id': 'pl', 'name': 'Polski', 'flag': '🇵🇱'},
    {'id': 'ar', 'name': 'العربية', 'flag': '🇸🇦'},
  ];

  // Available avatars
  final List<String> avatars = [
    'default',
    'cat',
    'dog',
    'robot',
    'star',
    'heart',
    'rocket',
    'tree',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => isLoading = true);

    try {
      final user = currentUser;
      if (user == null) return;

      final data = await supabase
          .from('users')
          .select('display_name, theme, locale, avatar')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _displayNameController.text = data['display_name'] as String? ?? '';
          selectedThemeId = data['theme'] as String? ?? 'cartoony';
          selectedLanguage = data['locale'] as String? ?? 'nl';
          selectedAvatar = data['avatar'] as String? ?? 'default';
          isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.debug('[PROFILE] Error loading profile: $e');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij laden: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      final user = currentUser;
      if (user == null) return;

      // Update database
      await supabase.from('users').update({
        'display_name': _displayNameController.text.trim(),
        'theme': selectedThemeId,
        'locale': selectedLanguage,
        'avatar': selectedAvatar,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      // Update theme provider
      final newTheme = AppThemeData.fromString(selectedThemeId);
      await ref.read(themeProvider.notifier).setTheme(newTheme);

      if (mounted) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profiel opgeslagen!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      AppLogger.debug('[PROFILE] Error saving profile: $e');
      if (mounted) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij opslaan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changeThemePreview(String themeId) async {
    setState(() => selectedThemeId = themeId);
    // Instant preview without saving to database
    final newTheme = AppThemeData.fromString(themeId);
    // Temporarily change theme for preview
    await ref.read(themeProvider.notifier).setTheme(newTheme);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiel Instellingen'),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar Section
                    _buildAvatarSection(theme),
                    const SizedBox(height: 32),

                    // Display Name
                    _buildDisplayNameSection(theme),
                    const SizedBox(height: 24),

                    // Theme Selector
                    _buildThemeSelector(theme),
                    const SizedBox(height: 24),

                    // Language Picker
                    _buildLanguagePicker(theme),
                    const SizedBox(height: 24),

                    // Change Password Section
                    _buildChangePasswordSection(theme),
                    const SizedBox(height: 24),

                    // Subscription Management Section
                    _buildSubscriptionSection(theme),
                    const SizedBox(height: 24),

                    // Danger Zone Section
                    _buildDangerZoneSection(theme),
                    const SizedBox(height: 32),

                    // Save Button
                    FilledButton.icon(
                      onPressed: isSaving ? null : _saveProfile,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(isSaving ? 'Opslaan...' : 'Profiel Opslaan'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatarSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Avatar',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: avatars.length,
                itemBuilder: (context, index) {
                  final avatar = avatars[index];
                  final isSelected = selectedAvatar == avatar;

                  return GestureDetector(
                    onTap: () => setState(() => selectedAvatar = avatar),
                    child: Container(
                      width: 70,
                      height: 70,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _getAvatarEmoji(avatar),
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayNameSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weergavenaam',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _displayNameController,
              decoration: InputDecoration(
                hintText: 'Vul je naam in',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Naam is verplicht';
                }
                if (value.trim().length < 2) {
                  return 'Naam moet minimaal 2 tekens bevatten';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(ThemeData theme) {
    final allThemes = AppThemeData.allThemes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Thema',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Live Preview',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...allThemes.map((themeData) {
              final isSelected = selectedThemeId == themeData.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _changeThemePreview(themeData.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          themeData.icon,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                themeData.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getThemeDescription(themeData.type),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle, color: theme.colorScheme.error),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguagePicker(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Taal',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...languages.map((language) {
              final isSelected = selectedLanguage == language['id'];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => setState(() => selectedLanguage = language['id']),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          language['flag'],
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          language['name'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          Icon(Icons.check_circle, color: theme.colorScheme.error),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getAvatarEmoji(String avatar) {
    switch (avatar) {
      case 'cat':
        return '🐱';
      case 'dog':
        return '🐶';
      case 'robot':
        return '🤖';
      case 'star':
        return '⭐';
      case 'heart':
        return '❤️';
      case 'rocket':
        return '🚀';
      case 'tree':
        return '🌳';
      default:
        return '👤';
    }
  }

  String _getThemeDescription(AppThemeType type) {
    switch (type) {
      case AppThemeType.cartoony:
        return 'Vrolijk en speels (Kids 6-10)';
      case AppThemeType.space:
        return 'Cosmic en futuristisch (Boys 10-15)';
      case AppThemeType.stylish:
        return 'Elegant en stijlvol (Girls 10-15)';
      case AppThemeType.minimal:
        return 'Strak en modern (Teens 15+)';
      case AppThemeType.classy:
        return 'Warm en klassiek (Ouders)';
      case AppThemeType.dark:
        return 'Donker en comfortabel (Alle leeftijden)';
    }
  }

  Widget _buildChangePasswordSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Wachtwoord wijzigen',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  Icons.lock_outline,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Current password field
            TextFormField(
              controller: _currentPasswordController,
              obscureText: !showCurrentPassword,
              decoration: InputDecoration(
                labelText: 'Huidig wachtwoord',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    showCurrentPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => showCurrentPassword = !showCurrentPassword);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              enabled: !isChangingPassword,
            ),
            const SizedBox(height: 16),

            // New password field
            TextFormField(
              controller: _newPasswordController,
              obscureText: !showNewPassword,
              decoration: InputDecoration(
                labelText: 'Nieuw wachtwoord',
                hintText: 'Min. 8 tekens, 1 hoofdletter, 1 cijfer, 1 speciaal teken',
                prefixIcon: const Icon(Icons.lock_reset),
                suffixIcon: IconButton(
                  icon: Icon(
                    showNewPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => showNewPassword = !showNewPassword);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              enabled: !isChangingPassword,
            ),
            const SizedBox(height: 16),

            // Confirm new password field
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !showConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Bevestig nieuw wachtwoord',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => showConfirmPassword = !showConfirmPassword);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              enabled: !isChangingPassword,
            ),
            const SizedBox(height: 16),

            // Change password button
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: isChangingPassword ? null : _changePassword,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: isChangingPassword
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(isChangingPassword ? 'Wijzigen...' : 'Wachtwoord wijzigen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    // Validate inputs
    if (_currentPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voer je huidige wachtwoord in'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_newPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voer een nieuw wachtwoord in'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate new password requirements
    final newPassword = _newPasswordController.text;
    if (newPassword.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wachtwoord moet minimaal 8 tekens bevatten'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!RegExp(r'[A-Z]').hasMatch(newPassword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wachtwoord moet minimaal 1 hoofdletter bevatten'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!RegExp(r'[0-9]').hasMatch(newPassword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wachtwoord moet minimaal 1 cijfer bevatten'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(newPassword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wachtwoord moet minimaal 1 speciaal teken bevatten'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wachtwoorden komen niet overeen'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isChangingPassword = true);

    try {
      // First verify current password by re-authenticating
      final user = currentUser;
      if (user == null || user.email == null) {
        throw Exception('Geen gebruiker gevonden');
      }

      // Re-authenticate with current password
      await supabase.auth.signInWithPassword(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      // If re-authentication succeeds, update to new password
      await supabase.auth.updateUser(
        UserAttributes(
          password: _newPasswordController.text,
        ),
      );

      if (mounted) {
        setState(() => isChangingPassword = false);

        // Clear password fields
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wachtwoord succesvol gewijzigd!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => isChangingPassword = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message == 'Invalid login credentials'
                  ? 'Huidig wachtwoord is onjuist'
                  : e.message,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isChangingPassword = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij wijzigen wachtwoord: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSubscriptionSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Abonnement',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  Icons.stars,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Current tier display
            Row(
              children: [
                Icon(
                  Icons.verified,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Gratis',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Upgrade button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/premium');
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.upgrade),
                label: const Text('Upgrade naar Premium'),
              ),
            ),

            const SizedBox(height: 12),

            // Features preview
            Text(
              'Premium voordelen:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildFeatureItem(theme, 'Onbeperkt gezinsleden'),
            _buildFeatureItem(theme, 'Geen advertenties'),
            _buildFeatureItem(theme, 'Onbeperkte AI-functies'),
            _buildFeatureItem(theme, 'Alle thema\'s'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZoneSection(ThemeData theme) {
    return Card(
      color: Colors.red.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.red.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_rounded,
                  color: Colors.red[700],
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Gevarenzone',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Permanente acties die niet ongedaan gemaakt kunnen worden',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Export Data Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/settings/data-export');
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: theme.colorScheme.primary),
                ),
                icon: const Icon(Icons.download),
                label: const Text('Gegevens Exporteren'),
              ),
            ),
            const SizedBox(height: 12),

            // Delete Account Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/settings/delete-account');
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                ),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Account Verwijderen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
