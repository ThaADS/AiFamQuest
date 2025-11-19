import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/supabase.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_logger.dart';

/// Family Invite Screen
///
/// Features:
/// - Generate unique invite code
/// - Select role for new member (parent/teen/child)
/// - Copy invite link to clipboard
/// - Share invite link via native share
/// - Show pending invites
class FamilyInviteScreen extends StatefulWidget {
  const FamilyInviteScreen({super.key});

  @override
  State<FamilyInviteScreen> createState() => _FamilyInviteScreenState();
}

class _FamilyInviteScreenState extends State<FamilyInviteScreen> {
  String selectedRole = 'child';
  String? inviteCode;
  bool isGenerating = false;
  String? familyId;

  // Mocha Mousse color scheme
  static const mochaBrown = Color(0xFF6B4423);
  static const lightMocha = Color(0xFFB08968);
  static const cream = Color(0xFFF5EBE0);
  static const darkMocha = Color(0xFF3D2817);

  @override
  void initState() {
    super.initState();
    _getFamilyId();
  }

  Future<void> _getFamilyId() async {
    try {
      final user = currentUser;
      if (user == null) return;

      final userData = await supabase
          .from('users')
          .select('family_id')
          .eq('id', user.id)
          .single();

      setState(() {
        familyId = userData['family_id'] as String;
      });
    } catch (e) {
      AppLogger.debug('[INVITE] Error getting family ID: $e');
    }
  }

  Future<void> _generateInviteCode() async {
    setState(() => isGenerating = true);

    try {
      // Generate a random 6-character code
      final code = _generateRandomCode();

      // For now, we'll just generate the code
      // In a real implementation, this would be stored in the database
      setState(() {
        inviteCode = code;
        isGenerating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uitnodigingscode gegenereerd!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      AppLogger.debug('[INVITE] Error generating code: $e');
      if (mounted) {
        setState(() => isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij genereren: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var code = '';
    for (var i = 0; i < 6; i++) {
      code += chars[(random + i) % chars.length];
    }
    return code;
  }

  String _getInviteLink() {
    // In production, this would be your app's deep link
    return 'https://famquest.app/invite/$inviteCode?role=$selectedRole';
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _getInviteLink()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link gekopieerd naar klembord!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareInvite() {
    final message = '''
Je bent uitgenodigd voor FamQuest!

Rol: ${_getRoleLabel(selectedRole)}
Code: $inviteCode

Gebruik deze link om lid te worden:
${_getInviteLink()}
''';

    Share.share(message, subject: 'FamQuest Uitnodiging');
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'parent':
        return 'Ouder';
      case 'teen':
        return 'Tiener';
      case 'child':
        return 'Kind';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: mochaBrown,
        foregroundColor: Colors.white,
        title: const Text('Familie Uitnodigen'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Illustration/Icon
            Icon(
              Icons.family_restroom,
              size: 80,
              color: mochaBrown.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Nodig een gezinslid uit',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: darkMocha,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecteer een rol en genereer een uitnodigingscode',
              style: TextStyle(
                color: mochaBrown,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Role Selector
            Card(
              elevation: 2,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selecteer rol',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: darkMocha,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildRoleOption('parent', 'Ouder', Icons.supervisor_account,
                        'Volledige toegang tot alle functies'),
                    const SizedBox(height: 12),
                    _buildRoleOption('teen', 'Tiener', Icons.person,
                        'Kan taken doen en punten verdienen'),
                    const SizedBox(height: 12),
                    _buildRoleOption('child', 'Kind', Icons.child_care,
                        'Beperkte toegang met ouderlijk toezicht'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Generate Button
            if (inviteCode == null)
              FilledButton.icon(
                onPressed: isGenerating ? null : _generateInviteCode,
                style: FilledButton.styleFrom(
                  backgroundColor: mochaBrown,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.add_link),
                label: Text(isGenerating ? 'Genereren...' : 'Genereer Uitnodiging'),
              ),

            // Generated Invite Card
            if (inviteCode != null) ...[
              Card(
                elevation: 4,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Uitnodigingscode',
                        style: TextStyle(
                          fontSize: 14,
                          color: mochaBrown,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: cream,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: mochaBrown, width: 2),
                        ),
                        child: Text(
                          inviteCode!,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: mochaBrown,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _copyToClipboard,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                foregroundColor: mochaBrown,
                                side: const BorderSide(color: mochaBrown),
                              ),
                              icon: const Icon(Icons.copy, size: 20),
                              label: const Text('Kopieer'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _shareInvite,
                              style: FilledButton.styleFrom(
                                backgroundColor: mochaBrown,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.share, size: 20),
                              label: const Text('Delen'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: lightMocha.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 20, color: mochaBrown),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Deel deze code met het nieuwe gezinslid',
                                style: TextStyle(
                                  color: darkMocha,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  setState(() => inviteCode = null);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Nieuwe code genereren'),
                style: TextButton.styleFrom(
                  foregroundColor: mochaBrown,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoleOption(
    String role,
    String label,
    IconData icon,
    String description,
  ) {
    final isSelected = selectedRole == role;

    return InkWell(
      onTap: () => setState(() => selectedRole = role),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? mochaBrown.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? mochaBrown : lightMocha,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: role,
              onChanged: (value) => setState(() => selectedRole = value!),
              activeColor: mochaBrown,
            ),
            const SizedBox(width: 12),
            Icon(icon, color: isSelected ? mochaBrown : lightMocha, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? mochaBrown : darkMocha,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: mochaBrown,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
