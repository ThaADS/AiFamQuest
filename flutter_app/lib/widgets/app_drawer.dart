import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/supabase.dart';
import '../providers/notification_provider.dart';

/// Main navigation drawer for FamQuest app
/// Shows different menu items based on user role (parent/teen/child/helper)
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mocha Mousse color scheme
    const mochaBrown = Color(0xFF6B4423);
    const lightMocha = Color(0xFFB08968);
    const cream = Color(0xFFF5EBE0);

    final user = currentUser;
    final unreadCount = ref.watch(unreadCountProvider);

    if (user == null) {
      return const Drawer(
        backgroundColor: cream,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Drawer(
      backgroundColor: cream,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer Header
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6B4423), Color(0xFF8B5A2B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Color(0xFF6B4423)),
                ),
                const SizedBox(height: 12),
                Text(
                  user.email ?? 'FamQuest User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Main Menu Items
          _buildMenuItem(
            context,
            icon: Icons.home,
            title: 'Home',
            route: '/home',
            color: mochaBrown,
          ),
          _buildMenuItem(
            context,
            icon: Icons.calendar_month,
            title: 'Kalender',
            route: '/calendar',
            color: mochaBrown,
          ),
          _buildMenuItem(
            context,
            icon: Icons.notifications,
            title: 'Meldingen',
            route: '/notifications',
            color: mochaBrown,
            badge: unreadCount > 0 ? unreadCount : null,
          ),

          const Divider(),

          // Gamification Section
          _buildSectionHeader('Gamification', mochaBrown),
          _buildMenuItem(
            context,
            icon: Icons.stars,
            title: 'Mijn Punten & Stats',
            route: '/gamification/stats',
            color: lightMocha,
          ),
          _buildMenuItem(
            context,
            icon: Icons.emoji_events,
            title: 'Badges',
            route: '/gamification/badges',
            color: lightMocha,
          ),
          _buildMenuItem(
            context,
            icon: Icons.leaderboard,
            title: 'Ranglijst',
            route: '/gamification/leaderboard',
            color: lightMocha,
          ),
          _buildMenuItem(
            context,
            icon: Icons.shopping_cart,
            title: 'Winkel',
            route: '/gamification/shop',
            color: lightMocha,
          ),

          const Divider(),

          // AI Features Section
          _buildSectionHeader('AI Functies', mochaBrown),
          _buildMenuItem(
            context,
            icon: Icons.camera_alt,
            title: 'Schoonmaak Tips (Foto)',
            route: '/vision',
            color: lightMocha,
          ),
          _buildMenuItem(
            context,
            icon: Icons.mic,
            title: 'Spraak Opdrachten',
            route: '/voice/task',
            color: lightMocha,
          ),
          _buildMenuItem(
            context,
            icon: Icons.school,
            title: 'Huiswerk Coach',
            route: '/study/planner',
            color: lightMocha,
          ),

          const Divider(),

          // Family Section
          _buildSectionHeader('Familie', mochaBrown),
          _buildMenuItem(
            context,
            icon: Icons.people,
            title: 'Familie Leden',
            route: '/family/members',
            color: lightMocha,
          ),
          _buildMenuItem(
            context,
            icon: Icons.person_add,
            title: 'Lid Uitnodigen',
            route: '/family/invite',
            color: lightMocha,
          ),

          const Divider(),

          // Tasks & Organization Section
          _buildSectionHeader('Taken & Planning', mochaBrown),
          _buildMenuItem(
            context,
            icon: Icons.repeat,
            title: 'Terugkerende Taken',
            route: '/tasks/recurring',
            color: lightMocha,
          ),
          _buildMenuItem(
            context,
            icon: Icons.balance,
            title: 'Eerlijkheidsdashboard',
            route: '/fairness',
            color: lightMocha,
          ),

          const Divider(),

          // Premium & Privacy Section
          _buildSectionHeader('Premium & Privacy', mochaBrown),
          _buildMenuItem(
            context,
            icon: Icons.workspace_premium,
            title: 'FamQuest Premium',
            route: '/premium',
            color: const Color(0xFFFFD700), // Gold color
          ),
          _buildMenuItem(
            context,
            icon: Icons.privacy_tip,
            title: 'Privacy Instellingen',
            route: '/settings/privacy',
            color: lightMocha,
          ),
          _buildMenuItem(
            context,
            icon: Icons.download,
            title: 'Gegevens Exporteren',
            route: '/settings/data-export',
            color: lightMocha,
          ),

          const Divider(),

          // Settings & Account
          _buildSectionHeader('Instellingen', mochaBrown),
          _buildMenuItem(
            context,
            icon: Icons.person,
            title: 'Profiel Instellingen',
            route: '/settings/profile',
            color: lightMocha,
          ),
          _buildMenuItem(
            context,
            icon: Icons.security,
            title: '2FA Beveiliging',
            route: '/settings/security',
            color: lightMocha,
          ),
          _buildMenuItem(
            context,
            icon: Icons.logout,
            title: 'Uitloggen',
            route: null, // Special handling
            color: Colors.red.shade700,
            onTap: () async {
              await supabaseAuth.signOut();
              if (context.mounted) {
                context.go('/');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String? route,
    required Color color,
    VoidCallback? onTap,
    int? badge,
  }) {
    return ListTile(
      leading: Badge(
        isLabelVisible: badge != null && badge > 0,
        label: badge != null && badge > 0 ? Text(badge.toString()) : null,
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF3D2817),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap ??
          () {
            if (route != null) {
              context.go(route);
              Navigator.pop(context); // Close drawer
            }
          },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      hoverColor: color.withValues(alpha: 0.1),
    );
  }
}
