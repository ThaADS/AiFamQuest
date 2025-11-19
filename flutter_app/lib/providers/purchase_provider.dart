/// Purchase Provider - Riverpod state management for in-app purchases
///
/// Manages:
/// - Current subscription tier
/// - Available products from stores
/// - Purchase flow state
/// - Purchase actions (buy, restore, cancel)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/purchase_models.dart';
import '../services/purchase_service.dart';

// Purchase service instance
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService();
});

// Current subscription status
final subscriptionStatusProvider = StreamProvider<SubscriptionStatus>((ref) {
  final service = ref.watch(purchaseServiceProvider);
  return service.subscriptionStream;
});

// Current tier (from subscription)
final currentTierProvider = Provider<PurchaseTier>((ref) {
  final subscription = ref.watch(subscriptionStatusProvider);
  return subscription.when(
    data: (sub) => sub.activeTier,
    loading: () => PurchaseTier.free,
    error: (_, __) => PurchaseTier.free,
  );
});

// Available products from store
final availableProductsProvider = Provider<Map<String, PurchaseProduct>>((ref) {
  final service = ref.watch(purchaseServiceProvider);
  return service.products;
});

// Get specific product by tier
final productProvider = Provider.family<PurchaseProduct?, PurchaseTier>((ref, tier) {
  final products = ref.watch(availableProductsProvider);
  return products[tier.id];
});

// Purchase in progress state
class PurchaseStateNotifier extends StateNotifier<PurchaseTier?> {
  PurchaseStateNotifier() : super(null);

  void setPurchasing(PurchaseTier? tier) {
    state = tier;
  }
}

final purchaseInProgressProvider = StateNotifierProvider<PurchaseStateNotifier, PurchaseTier?>((ref) {
  return PurchaseStateNotifier();
});

// Purchase result stream
final purchaseResultProvider = StreamProvider<PurchaseResult>((ref) {
  final service = ref.watch(purchaseServiceProvider);
  return service.purchaseStream;
});

// Feature access checks
final hasPremiumProvider = Provider<bool>((ref) {
  final tier = ref.watch(currentTierProvider);
  return tier.isPremium;
});

final hasFamilyUnlockProvider = Provider<bool>((ref) {
  final tier = ref.watch(currentTierProvider);
  return tier.hasUnlimitedMembers;
});

final hasNoAdsProvider = Provider<bool>((ref) {
  final tier = ref.watch(currentTierProvider);
  return tier.hasNoAds;
});

final hasUnlimitedAIProvider = Provider<bool>((ref) {
  final tier = ref.watch(currentTierProvider);
  return tier.hasUnlimitedAI;
});

// Purchase actions
class PurchaseActions {
  final Ref ref;

  PurchaseActions(this.ref);

  Future<PurchaseResult> purchaseProduct(PurchaseTier tier) async {
    final service = ref.read(purchaseServiceProvider);
    ref.read(purchaseInProgressProvider.notifier).setPurchasing(tier);

    try {
      final result = await service.purchaseProduct(tier);
      return result;
    } finally {
      ref.read(purchaseInProgressProvider.notifier).setPurchasing(null);
    }
  }

  Future<PurchaseResult> restorePurchases() async {
    final service = ref.read(purchaseServiceProvider);
    return service.restorePurchases();
  }

  Future<void> fetchSubscriptionStatus() async {
    final service = ref.read(purchaseServiceProvider);
    await service.fetchSubscriptionStatus();
  }

  bool canAccessFeature(String feature) {
    final tier = ref.read(currentTierProvider);

    switch (feature) {
      case 'unlimited_members':
        return tier.hasUnlimitedMembers;
      case 'no_ads':
        return tier.hasNoAds;
      case 'unlimited_ai':
        return tier.hasUnlimitedAI;
      case 'all_themes':
        return tier.hasAllThemes;
      default:
        return false;
    }
  }

  PurchaseTier getRequiredTierForFeature(String feature) {
    switch (feature) {
      case 'unlimited_members':
        return PurchaseTier.familyUnlock;
      case 'no_ads':
        return PurchaseTier.familyUnlock;
      case 'unlimited_ai':
      case 'all_themes':
      case 'analytics':
        return PurchaseTier.premiumMonthly;
      default:
        return PurchaseTier.free;
    }
  }
}

final purchaseActionsProvider = Provider<PurchaseActions>((ref) {
  return PurchaseActions(ref);
});

// AI request count tracking
class AIRequestCountNotifier extends StateNotifier<int> {
  AIRequestCountNotifier() : super(0);

  void increment() {
    state++;
  }

  void reset() {
    state = 0;
  }

  bool hasReachedLimit(bool hasPremium) {
    if (hasPremium) return false;
    return state >= 5; // Free tier: 5 requests per day
  }
}

final aiRequestCountProvider = StateNotifierProvider<AIRequestCountNotifier, int>((ref) {
  return AIRequestCountNotifier();
});

// Family member count tracking
class FamilyMemberCountNotifier extends StateNotifier<int> {
  FamilyMemberCountNotifier() : super(0);

  void setCount(int count) {
    state = count;
  }

  bool hasReachedLimit(bool hasFamilyUnlock) {
    if (hasFamilyUnlock) return false;
    return state >= 4; // Free tier: max 4 members
  }
}

final familyMemberCountProvider = StateNotifierProvider<FamilyMemberCountNotifier, int>((ref) {
  return FamilyMemberCountNotifier();
});
