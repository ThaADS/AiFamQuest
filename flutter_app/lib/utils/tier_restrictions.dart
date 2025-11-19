import 'package:flutter/material.dart';
import '../models/purchase_models.dart';
import '../features/premium/premium_screen.dart';

/// Tier Restriction Helper
///
/// Provides utility methods for checking and enforcing tier restrictions
/// throughout the app. Shows upgrade prompts when features are restricted.
class TierRestrictions {
  /// Show upgrade dialog when a feature is restricted
  static Future<bool> showUpgradeDialog(
    BuildContext context, {
    required String feature,
    required PurchaseTier requiredTier,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.workspace_premium,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Premium Functie'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deze functie is alleen beschikbaar in ${requiredTier.displayName}.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              _getFeatureDescription(feature),
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Upgrade nu'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PremiumScreen(),
        ),
      );
      return true;
    }

    return false;
  }

  /// Check if user can access a feature, show upgrade dialog if not
  static Future<bool> checkAccess(
    BuildContext context, {
    required PurchaseTier currentTier,
    required String feature,
  }) async {
    final requiredTier = _getRequiredTier(feature);

    if (_hasAccess(currentTier, requiredTier)) {
      return true;
    }

    return showUpgradeDialog(
      context,
      feature: feature,
      requiredTier: requiredTier,
    );
  }

  /// Check if current tier has access to feature (no UI)
  static bool _hasAccess(PurchaseTier currentTier, PurchaseTier requiredTier) {
    // Free tier: no restrictions
    if (requiredTier == PurchaseTier.free) return true;

    // Family Unlock: grants unlimited members and no ads
    if (requiredTier == PurchaseTier.familyUnlock) {
      return currentTier == PurchaseTier.familyUnlock ||
          currentTier.isPremium;
    }

    // Premium features: require premium subscription
    if (requiredTier.isPremium) {
      return currentTier.isPremium;
    }

    return false;
  }

  /// Get required tier for a feature
  static PurchaseTier _getRequiredTier(String feature) {
    switch (feature) {
      case 'unlimited_members':
      case 'no_ads':
        return PurchaseTier.familyUnlock;
      case 'unlimited_ai':
      case 'all_themes':
      case 'advanced_analytics':
      case 'priority_support':
      case 'early_access':
        return PurchaseTier.premiumMonthly;
      default:
        return PurchaseTier.free;
    }
  }

  /// Get feature description for upgrade dialog
  static String _getFeatureDescription(String feature) {
    switch (feature) {
      case 'unlimited_members':
        return 'Voeg onbeperkt gezinsleden toe aan je FamQuest account.';
      case 'no_ads':
        return 'Geniet van een advertentievrije ervaring.';
      case 'unlimited_ai':
        return 'Onbeperkte AI-aanvragen voor planning, tips en studie-coach.';
      case 'all_themes':
        return 'Ontgrendel alle thema\'s en aanpassingsopties.';
      case 'advanced_analytics':
        return 'Bekijk gedetailleerde analyses en inzichten.';
      case 'priority_support':
        return 'Krijg prioriteitsondersteuning via live chat.';
      case 'early_access':
        return 'Krijg vroege toegang tot nieuwe functies.';
      default:
        return 'Deze functie is niet beschikbaar in je huidige abonnement.';
    }
  }

  /// Show limit reached dialog (e.g., family member limit, AI request limit)
  static Future<void> showLimitReachedDialog(
    BuildContext context, {
    required String limitType,
    required int currentCount,
    required int maxCount,
  }) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(child: Text('Limiet Bereikt')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getLimitMessage(limitType, currentCount, maxCount),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'Upgrade naar Family Unlock of Premium om deze limiet te verhogen.',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sluiten'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PremiumScreen(),
                ),
              );
            },
            child: const Text('Bekijk Premium'),
          ),
        ],
      ),
    );
  }

  static String _getLimitMessage(String limitType, int current, int max) {
    switch (limitType) {
      case 'family_members':
        return 'Je hebt het maximum aantal gezinsleden bereikt ($max). '
            'Je kunt niet meer gezinsleden toevoegen met het gratis abonnement.';
      case 'ai_requests':
        return 'Je hebt het dagelijkse limiet van $max AI-aanvragen bereikt. '
            'Probeer het morgen opnieuw of upgrade voor onbeperkte toegang.';
      default:
        return 'Je hebt de limiet bereikt voor dit abonnement ($current/$max).';
    }
  }

  /// Show premium badge widget
  static Widget premiumBadge({
    bool isSmall = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            size: isSmall ? 12 : 16,
            color: Colors.white,
          ),
          SizedBox(width: isSmall ? 4 : 6),
          Text(
            'PREMIUM',
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmall ? 10 : 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Show "Upgrade to unlock" button
  static Widget upgradeButton(
    BuildContext context, {
    required String feature,
    VoidCallback? onUpgrade,
    bool isCompact = false,
  }) {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PremiumScreen(),
          ),
        );
        onUpgrade?.call();
      },
      icon: const Icon(Icons.lock_open, size: 18),
      label: Text(isCompact ? 'Upgrade' : 'Upgrade om te ontgrendelen'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.orange,
        side: const BorderSide(color: Colors.orange),
      ),
    );
  }
}
