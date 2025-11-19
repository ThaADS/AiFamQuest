import 'package:flutter/material.dart';

/// Empty State Widget
///
/// Reusable component for showing empty states across the app.
/// Features:
/// - Consistent design language
/// - Customizable icon, title, message, and action
/// - Accessibility support with semantic labels
/// - Responsive sizing
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor =
        iconColor ?? theme.colorScheme.primary.withValues(alpha: 0.5);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: effectiveIconColor,
                semanticLabel: title,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            // Action button (optional)
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty State Factory
///
/// Predefined empty states for common scenarios
class EmptyStates {
  EmptyStates._();

  /// No tasks yet
  static Widget noTasks({VoidCallback? onCreateTask}) {
    return EmptyStateWidget(
      icon: Icons.task_alt,
      title: 'Geen taken',
      message: 'Je hebt nog geen taken. Maak je eerste taak aan om te beginnen!',
      actionLabel: onCreateTask != null ? 'Taak Toevoegen' : null,
      onAction: onCreateTask,
    );
  }

  /// No events yet
  static Widget noEvents({VoidCallback? onCreateEvent}) {
    return EmptyStateWidget(
      icon: Icons.calendar_today,
      title: 'Geen evenementen',
      message:
          'Je agenda is leeg. Voeg een evenement toe om je planning te beheren.',
      actionLabel: onCreateEvent != null ? 'Evenement Toevoegen' : null,
      onAction: onCreateEvent,
    );
  }

  /// No family members yet
  static Widget noFamilyMembers({VoidCallback? onInvite}) {
    return EmptyStateWidget(
      icon: Icons.people,
      title: 'Geen familieleden',
      message: 'Nodig familieleden uit om samen te werken!',
      actionLabel: onInvite != null ? 'Familielid Uitnodigen' : null,
      onAction: onInvite,
    );
  }

  /// No notifications
  static Widget noNotifications() {
    return const EmptyStateWidget(
      icon: Icons.notifications_none,
      title: 'Geen meldingen',
      message: 'Je bent helemaal bij! Er zijn geen nieuwe meldingen.',
      iconColor: Colors.green,
    );
  }

  /// No rewards available
  static Widget noRewards() {
    return const EmptyStateWidget(
      icon: Icons.card_giftcard,
      title: 'Geen beloningen',
      message:
          'Er zijn momenteel geen beloningen beschikbaar. Spaar meer punten!',
    );
  }

  /// No badges earned
  static Widget noBadges() {
    return const EmptyStateWidget(
      icon: Icons.emoji_events,
      title: 'Nog geen badges',
      message: 'Voltooi taken om je eerste badge te verdienen!',
    );
  }

  /// No study items
  static Widget noStudyItems({VoidCallback? onCreateStudyItem}) {
    return EmptyStateWidget(
      icon: Icons.school,
      title: 'Geen studieplannen',
      message: 'Maak je eerste studieplan aan voor betere voorbereiding!',
      actionLabel: onCreateStudyItem != null ? 'Studieplan Maken' : null,
      onAction: onCreateStudyItem,
    );
  }

  /// No points/activity
  static Widget noActivity() {
    return const EmptyStateWidget(
      icon: Icons.insights,
      title: 'Nog geen activiteit',
      message:
          'Begin met taken voltooien om je activiteitsgeschiedenis te zien!',
    );
  }

  /// Search no results
  static Widget noSearchResults(String query) {
    return EmptyStateWidget(
      icon: Icons.search_off,
      title: 'Geen resultaten',
      message: 'Geen resultaten gevonden voor "$query". Probeer een andere zoekopdracht.',
    );
  }

  /// No helpers
  static Widget noHelpers({VoidCallback? onInviteHelper}) {
    return EmptyStateWidget(
      icon: Icons.support_agent,
      title: 'Geen helpers',
      message: 'Je hebt nog geen helpers. Nodig iemand uit om te helpen!',
      actionLabel: onInviteHelper != null ? 'Helper Uitnodigen' : null,
      onAction: onInviteHelper,
    );
  }

  /// No pending approvals
  static Widget noPendingApprovals() {
    return const EmptyStateWidget(
      icon: Icons.check_circle_outline,
      title: 'Geen wachtende goedkeuringen',
      message: 'Er zijn geen taken die op goedkeuring wachten.',
      iconColor: Colors.green,
    );
  }

  /// Connection error
  static Widget connectionError({VoidCallback? onRetry}) {
    return EmptyStateWidget(
      icon: Icons.cloud_off,
      title: 'Geen verbinding',
      message:
          'Kan geen verbinding maken met de server. Controleer je internetverbinding.',
      actionLabel: onRetry != null ? 'Opnieuw Proberen' : null,
      onAction: onRetry,
      iconColor: Colors.orange,
    );
  }

  /// Generic error
  static Widget error({
    required String message,
    VoidCallback? onRetry,
  }) {
    return EmptyStateWidget(
      icon: Icons.error_outline,
      title: 'Er ging iets mis',
      message: message,
      actionLabel: onRetry != null ? 'Opnieuw Proberen' : null,
      onAction: onRetry,
      iconColor: Colors.red,
    );
  }

  /// Loading skeleton (not truly empty, but useful for loading states)
  static Widget loading({String message = 'Laden...'}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
