/// Purchase Models for FamQuest In-App Purchases
///
/// Defines the purchase tiers, product information, and purchase status
/// for both App Store and Google Play Store integration.

/// Purchase Tier Types
enum PurchaseTier {
  free('free', 'Free', 0.0),
  familyUnlock('family_unlock', 'Family Unlock', 19.99),
  premiumMonthly('premium_monthly', 'Premium Monthly', 4.99),
  premiumYearly('premium_yearly', 'Premium Yearly', 49.99);

  final String id;
  final String displayName;
  final double price;

  const PurchaseTier(this.id, this.displayName, this.price);

  static PurchaseTier fromString(String value) {
    switch (value) {
      case 'family_unlock':
        return PurchaseTier.familyUnlock;
      case 'premium_monthly':
        return PurchaseTier.premiumMonthly;
      case 'premium_yearly':
        return PurchaseTier.premiumYearly;
      default:
        return PurchaseTier.free;
    }
  }

  bool get isPremium =>
      this == PurchaseTier.premiumMonthly || this == PurchaseTier.premiumYearly;
  bool get isFamilyUnlock => this == PurchaseTier.familyUnlock;
  bool get hasUnlimitedMembers => isPremium || isFamilyUnlock;
  bool get hasNoAds => isPremium || isFamilyUnlock;
  bool get hasUnlimitedAI => isPremium;
  bool get hasAllThemes => isPremium;
}

/// Product IDs for iOS and Android
class ProductIds {
  // iOS Product IDs (App Store Connect)
  static const String iosFamilyUnlock = 'com.famquest.family_unlock';
  static const String iosPremiumMonthly = 'com.famquest.premium_monthly';
  static const String iosPremiumYearly = 'com.famquest.premium_yearly';

  // Android Product IDs (Google Play Console)
  static const String androidFamilyUnlock = 'family_unlock';
  static const String androidPremiumMonthly = 'premium_monthly';
  static const String androidPremiumYearly = 'premium_yearly';

  // All product IDs (for store initialization)
  static const Set<String> allProductIds = {
    // iOS
    iosFamilyUnlock,
    iosPremiumMonthly,
    iosPremiumYearly,
    // Android
    androidFamilyUnlock,
    androidPremiumMonthly,
    androidPremiumYearly,
  };

  // Get platform-specific product ID
  static String getProductId(PurchaseTier tier, bool isIOS) {
    if (isIOS) {
      switch (tier) {
        case PurchaseTier.familyUnlock:
          return iosFamilyUnlock;
        case PurchaseTier.premiumMonthly:
          return iosPremiumMonthly;
        case PurchaseTier.premiumYearly:
          return iosPremiumYearly;
        default:
          return '';
      }
    } else {
      switch (tier) {
        case PurchaseTier.familyUnlock:
          return androidFamilyUnlock;
        case PurchaseTier.premiumMonthly:
          return androidPremiumMonthly;
        case PurchaseTier.premiumYearly:
          return androidPremiumYearly;
        default:
          return '';
      }
    }
  }

  // Get tier from product ID
  static PurchaseTier? getTierFromProductId(String productId) {
    switch (productId) {
      case iosFamilyUnlock:
      case androidFamilyUnlock:
        return PurchaseTier.familyUnlock;
      case iosPremiumMonthly:
      case androidPremiumMonthly:
        return PurchaseTier.premiumMonthly;
      case iosPremiumYearly:
      case androidPremiumYearly:
        return PurchaseTier.premiumYearly;
      default:
        return null;
    }
  }
}

/// Purchase Product Information
class PurchaseProduct {
  final PurchaseTier tier;
  final dynamic productDetails; // Using dynamic to avoid import conflicts
  final bool isAvailable;

  PurchaseProduct({
    required this.tier,
    this.productDetails,
    this.isAvailable = false,
  });

  String get id => tier.id;
  String get title => productDetails?.title ?? tier.displayName;
  String get description => productDetails?.description ?? _getDescription();
  String get price => productDetails?.price ?? '€${tier.price}';
  String get rawPrice => productDetails?.rawPrice?.toString() ?? tier.price.toString();

  String _getDescription() {
    switch (tier) {
      case PurchaseTier.familyUnlock:
        return 'Eenmalige aankoop - Onbeperkt gezinsleden + Geen advertenties';
      case PurchaseTier.premiumMonthly:
        return 'Maandelijks abonnement - Alle functies + Onbeperkte AI';
      case PurchaseTier.premiumYearly:
        return 'Jaarlijks abonnement - Alle functies + Onbeperkte AI (2 maanden gratis!)';
      default:
        return '';
    }
  }

  List<String> get features {
    switch (tier) {
      case PurchaseTier.familyUnlock:
        return [
          'Onbeperkt gezinsleden',
          'Geen advertenties',
          'Prioriteitsondersteuning',
        ];
      case PurchaseTier.premiumMonthly:
      case PurchaseTier.premiumYearly:
        return [
          'Onbeperkt gezinsleden',
          'Geen advertenties',
          'Onbeperkte AI-functies',
          'Alle thema\'s',
          'Geavanceerde analyses',
          'Prioriteitsondersteuning',
          'Live chat ondersteuning',
          'Vroege toegang tot nieuwe functies',
        ];
      default:
        return [];
    }
  }

  String? get savingsText {
    if (tier == PurchaseTier.premiumYearly) {
      return 'Bespaar €10 per jaar!';
    }
    return null;
  }
}

/// Purchase Status (renamed to avoid conflict with in_app_purchase package)
enum FamQuestPurchaseStatus {
  pending,
  purchased,
  error,
  canceled,
  restored,
  verified,
}

/// Purchase Result
class PurchaseResult {
  final FamQuestPurchaseStatus status;
  final PurchaseTier? tier;
  final String? error;
  final dynamic purchaseDetails; // Using dynamic to avoid import conflicts
  final bool needsVerification;

  PurchaseResult({
    required this.status,
    this.tier,
    this.error,
    this.purchaseDetails,
    this.needsVerification = false,
  });

  bool get isSuccess => status == FamQuestPurchaseStatus.purchased || status == FamQuestPurchaseStatus.verified;
  bool get isPending => status == FamQuestPurchaseStatus.pending;
  bool get hasError => status == FamQuestPurchaseStatus.error;
}

/// Subscription Status
class SubscriptionStatus {
  final PurchaseTier activeTier;
  final DateTime? expiryDate;
  final bool isActive;
  final bool autoRenew;
  final String? platform;

  SubscriptionStatus({
    required this.activeTier,
    this.expiryDate,
    required this.isActive,
    this.autoRenew = false,
    this.platform,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      activeTier: PurchaseTier.fromString(json['tier'] ?? 'free'),
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'])
          : null,
      isActive: json['is_active'] ?? false,
      autoRenew: json['auto_renew'] ?? false,
      platform: json['platform'],
    );
  }

  Map<String, dynamic> toJson() => {
    'tier': activeTier.id,
    'expiry_date': expiryDate?.toIso8601String(),
    'is_active': isActive,
    'auto_renew': autoRenew,
    'platform': platform,
  };

  bool get isPremium => activeTier.isPremium;
  bool get hasFamilyUnlock => activeTier.hasUnlimitedMembers;
  bool get hasNoAds => activeTier.hasNoAds;
  bool get hasUnlimitedAI => activeTier.hasUnlimitedAI;

  String get displayText {
    if (!isActive) return 'Gratis';
    if (activeTier == PurchaseTier.familyUnlock) {
      return 'Family Unlock';
    }
    return 'Premium';
  }

  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  bool get isExpiringSoon {
    final days = daysUntilExpiry;
    return days != null && days > 0 && days <= 7;
  }
}

/// Purchase Verification Request
class PurchaseVerificationRequest {
  final String productId;
  final String transactionId;
  final String receipt;
  final String platform; // 'ios' or 'android'

  PurchaseVerificationRequest({
    required this.productId,
    required this.transactionId,
    required this.receipt,
    required this.platform,
  });

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'transaction_id': transactionId,
    'receipt': receipt,
    'platform': platform,
  };
}

/// Purchase Verification Response
class PurchaseVerificationResponse {
  final bool isValid;
  final PurchaseTier? tier;
  final DateTime? expiryDate;
  final String? error;

  PurchaseVerificationResponse({
    required this.isValid,
    this.tier,
    this.expiryDate,
    this.error,
  });

  factory PurchaseVerificationResponse.fromJson(Map<String, dynamic> json) {
    return PurchaseVerificationResponse(
      isValid: json['is_valid'] ?? false,
      tier: json['tier'] != null ? PurchaseTier.fromString(json['tier']) : null,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'])
          : null,
      error: json['error'],
    );
  }
}
