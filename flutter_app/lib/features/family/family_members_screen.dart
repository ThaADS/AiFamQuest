import 'package:flutter/material.dart';
import '../../core/supabase.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/sync_status_widget.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_logger.dart';

/// Family Members Management Screen
///
/// Features:
/// - List all family members with roles
/// - Show member status (active, helper, pending)
/// - Edit roles (parent can change teen/child roles)
/// - Remove members
/// - Invite new members button
/// - Offline-first with sync support
class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  List<Map<String, dynamic>> members = [];
  bool isLoading = true;
  String? familyName;

  // Mocha Mousse color scheme
  static const mochaBrown = Color(0xFF6B4423);
  static const lightMocha = Color(0xFFB08968);
  static const cream = Color(0xFFF5EBE0);
  static const darkMocha = Color(0xFF3D2817);

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();
  }

  Future<void> _loadFamilyMembers() async {
    setState(() => isLoading = true);

    try {
      final user = currentUser;
      if (user == null) return;

      // Get user's family_id and family name
      final userData = await supabase
          .from('users')
          .select('family_id')
          .eq('id', user.id)
          .single();

      final familyId = userData['family_id'] as String;

      // Get family name
      final familyData = await supabase
          .from('families')
          .select('name')
          .eq('id', familyId)
          .single();

      // Get all family members
      final membersData = await supabase
          .from('users')
          .select('id, display_name, email, role, created_at')
          .eq('family_id', familyId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          familyName = familyData['name'] as String?;
          members = List<Map<String, dynamic>>.from(membersData);
          isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.debug('[FAMILY] Error loading members: $e');
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

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'parent':
        return Icons.supervisor_account;
      case 'teen':
        return Icons.person;
      case 'child':
        return Icons.child_care;
      case 'helper':
        return Icons.support_agent;
      default:
        return Icons.person_outline;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'parent':
        return Colors.purple;
      case 'teen':
        return Colors.blue;
      case 'child':
        return Colors.green;
      case 'helper':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'parent':
        return 'Ouder';
      case 'teen':
        return 'Tiener';
      case 'child':
        return 'Kind';
      case 'helper':
        return 'Helper';
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
        title: Text(familyName ?? 'Familie Leden'),
        elevation: 0,
        actions: const [
          SyncStatusWidget(),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : OfflineIndicator(
              child: RefreshIndicator(
              onRefresh: _loadFamilyMembers,
              child: members.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group, size: 80, color: lightMocha),
                          SizedBox(height: 16),
                          Text(
                            'Geen familie leden gevonden',
                            style: TextStyle(
                              fontSize: 20,
                              color: darkMocha,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Nodig leden uit om te beginnen',
                            style: TextStyle(color: mochaBrown),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final displayName = member['display_name'] as String? ?? 'Onbekend';
                        final email = member['email'] as String? ?? '';
                        final role = member['role'] as String? ?? 'unknown';
                        final isCurrentUser = member['id'] == currentUser?.id;

                        return Card(
                          elevation: 2,
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isCurrentUser ? mochaBrown : lightMocha,
                              width: isCurrentUser ? 2 : 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getRoleColor(role).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getRoleIcon(role),
                                color: _getRoleColor(role),
                                size: 28,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: darkMocha,
                                    ),
                                  ),
                                ),
                                if (isCurrentUser)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: mochaBrown,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Jij',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getRoleColor(role).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _getRoleLabel(role),
                                        style: TextStyle(
                                          color: _getRoleColor(role),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (email.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      color: mochaBrown,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: !isCurrentUser
                                ? IconButton(
                                    icon: const Icon(Icons.more_vert),
                                    color: mochaBrown,
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Lid bewerken wordt binnenkort toegevoegd!',
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/family/invite'),
        backgroundColor: mochaBrown,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Uitnodigen'),
      ),
    );
  }
}
