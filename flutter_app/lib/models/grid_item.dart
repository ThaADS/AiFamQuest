import 'package:flutter/material.dart';

/// Grid item model for draggable home screen
/// Represents a feature/screen that can be arranged by the user
class GridItem {
  final String id;
  final String label;
  final IconData icon;
  final String route;
  final int position;
  final String category;
  final Color color;
  final bool hidden;

  const GridItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
    required this.position,
    required this.category,
    required this.color,
    this.hidden = false,
  });

  GridItem copyWith({
    String? id,
    String? label,
    IconData? icon,
    String? route,
    int? position,
    String? category,
    Color? color,
    bool? hidden,
  }) {
    return GridItem(
      id: id ?? this.id,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      route: route ?? this.route,
      position: position ?? this.position,
      category: category ?? this.category,
      color: color ?? this.color,
      hidden: hidden ?? this.hidden,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'icon': icon.codePoint,
      'route': route,
      'position': position,
      'category': category,
      'color': color.value,
      'hidden': hidden,
    };
  }

  factory GridItem.fromJson(Map<String, dynamic> json) {
    return GridItem(
      id: json['id'] as String,
      label: json['label'] as String,
      icon: IconData(json['icon'] as int, fontFamily: 'MaterialIcons'),
      route: json['route'] as String,
      position: json['position'] as int,
      category: json['category'] as String,
      color: Color(json['color'] as int),
      hidden: json['hidden'] as bool? ?? false,
    );
  }
}

/// Default grid items configuration
/// All 28+ features organized by category
class DefaultGridItems {
  static const mochaBrown = Color(0xFF6B4423);
  static const lightMocha = Color(0xFFB08968);
  static const cream = Color(0xFFF5EBE0);
  static const darkMocha = Color(0xFF3D2817);

  static List<GridItem> get items => [
        // Calendar (positions 0-2)
        const GridItem(
          id: 'calendar',
          label: 'Kalender',
          icon: Icons.calendar_month,
          route: '/calendar',
          position: 0,
          category: 'Kalender',
          color: Colors.blue,
        ),
        const GridItem(
          id: 'calendar_week',
          label: 'Week View',
          icon: Icons.view_week,
          route: '/calendar/week',
          position: 1,
          category: 'Kalender',
          color: Colors.blue,
        ),
        const GridItem(
          id: 'calendar_day',
          label: 'Dag View',
          icon: Icons.today,
          route: '/calendar/day',
          position: 2,
          category: 'Kalender',
          color: Colors.blue,
        ),

        // Tasks (positions 3-6)
        const GridItem(
          id: 'tasks_recurring',
          label: 'Taken',
          icon: Icons.repeat,
          route: '/tasks/recurring',
          position: 3,
          category: 'Taken',
          color: Colors.green,
        ),
        const GridItem(
          id: 'tasks_approval',
          label: 'Goedkeuring',
          icon: Icons.check_circle,
          route: '/tasks/approval',
          position: 4,
          category: 'Taken',
          color: Colors.green,
        ),
        const GridItem(
          id: 'fairness',
          label: 'Eerlijkheid',
          icon: Icons.balance,
          route: '/fairness',
          position: 5,
          category: 'Taken',
          color: Colors.green,
        ),

        // Gamification (positions 6-9)
        const GridItem(
          id: 'shop',
          label: 'Winkel',
          icon: Icons.shopping_cart,
          route: '/gamification/shop',
          position: 6,
          category: 'Gamificatie',
          color: Colors.amber,
        ),
        const GridItem(
          id: 'badges',
          label: 'Badges',
          icon: Icons.emoji_events,
          route: '/gamification/badges',
          position: 7,
          category: 'Gamificatie',
          color: Colors.amber,
        ),
        const GridItem(
          id: 'leaderboard',
          label: 'Ranglijst',
          icon: Icons.leaderboard,
          route: '/gamification/leaderboard',
          position: 8,
          category: 'Gamificatie',
          color: Colors.amber,
        ),
        const GridItem(
          id: 'stats',
          label: 'Mijn Stats',
          icon: Icons.stars,
          route: '/gamification/stats',
          position: 9,
          category: 'Gamificatie',
          color: Colors.amber,
        ),

        // AI Features (positions 10-13)
        const GridItem(
          id: 'ai_planner',
          label: 'AI Planner',
          icon: Icons.auto_awesome,
          route: '/ai/planner',
          position: 10,
          category: 'AI',
          color: Colors.purple,
        ),
        const GridItem(
          id: 'vision',
          label: 'Schoonmaak Tips',
          icon: Icons.camera_alt,
          route: '/vision',
          position: 11,
          category: 'AI',
          color: Colors.purple,
        ),
        const GridItem(
          id: 'voice',
          label: 'Spraak',
          icon: Icons.mic,
          route: '/voice/task',
          position: 12,
          category: 'AI',
          color: Colors.purple,
        ),
        const GridItem(
          id: 'study',
          label: 'Huiswerk Coach',
          icon: Icons.school,
          route: '/study/planner',
          position: 13,
          category: 'AI',
          color: Colors.purple,
        ),

        // Family (positions 14-16)
        const GridItem(
          id: 'family_members',
          label: 'Familie',
          icon: Icons.people,
          route: '/family/members',
          position: 14,
          category: 'Familie',
          color: Colors.orange,
        ),
        const GridItem(
          id: 'family_invite',
          label: 'Uitnodigen',
          icon: Icons.person_add,
          route: '/family/invite',
          position: 15,
          category: 'Familie',
          color: Colors.orange,
        ),
        const GridItem(
          id: 'helper_home',
          label: 'Helper',
          icon: Icons.support_agent,
          route: '/helper/home',
          position: 16,
          category: 'Familie',
          color: Colors.orange,
        ),

        // Kiosk (positions 17-18)
        const GridItem(
          id: 'kiosk_today',
          label: 'Kiosk Vandaag',
          icon: Icons.tv,
          route: '/kiosk/today',
          position: 17,
          category: 'Kiosk',
          color: Colors.cyan,
        ),
        const GridItem(
          id: 'kiosk_week',
          label: 'Kiosk Week',
          icon: Icons.weekend,
          route: '/kiosk/week',
          position: 18,
          category: 'Kiosk',
          color: Colors.cyan,
        ),

        // Settings (positions 19-21)
        const GridItem(
          id: 'profile',
          label: 'Profiel',
          icon: Icons.person,
          route: '/settings/profile',
          position: 19,
          category: 'Instellingen',
          color: mochaBrown,
        ),
        const GridItem(
          id: 'security',
          label: '2FA',
          icon: Icons.security,
          route: '/settings/security',
          position: 20,
          category: 'Instellingen',
          color: mochaBrown,
        ),
      ];
}
