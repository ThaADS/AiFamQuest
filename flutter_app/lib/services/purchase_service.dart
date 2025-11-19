/// Purchase Service for FamQuest In-App Purchases (Fixed Version)
///
/// Handles all purchase operations with proper platform-specific implementations

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import '../models/purchase_models.dart';
import '../api/client.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _isInitialized = false;
  bool _isAvailable = false;
  final Map<String, PurchaseProduct> _products = {};
  SubscriptionStatus? _currentSubscription;

  final _purchaseStateController = StreamController<PurchaseResult>.broadcast();
  final _subscriptionController = StreamController<SubscriptionStatus>.broadcast();

  bool get isAvailable => _isAvailable;
  bool get isInitialized => _isInitialized;
  Map<String, PurchaseProduct> get products => _products;
  SubscriptionStatus? get currentSubscription => _currentSubscription;
  Stream<PurchaseResult> get purchaseStream => _purchaseStateController.stream;
  Stream<SubscriptionStatus> get subscriptionStream => _subscriptionController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isAvailable = await _inAppPurchase.isAvailable();

      if (!_isAvailable) {
        debugPrint('[PURCHASE] Store not available');
        _isInitialized = true;
        return;
      }

      // Set up purchase listener
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => debugPrint('[PURCHASE] Stream closed'),
        onError: (error) => debugPrint('[PURCHASE] Stream error: $error'),
      );

      await loadProducts();
      await restorePurchases();
      await fetchSubscriptionStatus();

      _isInitialized = true;
      debugPrint('[PURCHASE] Initialized successfully');
    } catch (e) {
      debugPrint('[PURCHASE] Init error: $e');
      _isInitialized = true;
    }
  }

  Future<void> loadProducts() async {
    if (!_isAvailable) return;

    try {
      final response = await _inAppPurchase.queryProductDetails(ProductIds.allProductIds);

      if (response.error != null) {
        debugPrint('[PURCHASE] Error loading: ${response.error}');
        return;
      }

      _products.clear();
      for (final pd in response.productDetails) {
        final tier = ProductIds.getTierFromProductId(pd.id);
        if (tier != null) {
          _products[tier.id] = PurchaseProduct(
            tier: tier,
            productDetails: pd,
            isAvailable: true,
          );
        }
      }

      debugPrint('[PURCHASE] Loaded ${_products.length} products');
    } catch (e) {
      debugPrint('[PURCHASE] Load error: $e');
    }
  }

  Future<PurchaseResult> purchaseProduct(PurchaseTier tier) async {
    if (!_isAvailable) {
      return PurchaseResult(
        status: FamQuestPurchaseStatus.error,
        error: 'Store not available',
      );
    }

    final product = _products[tier.id];
    if (product?.productDetails == null) {
      return PurchaseResult(
        status: FamQuestPurchaseStatus.error,
        tier: tier,
        error: 'Product not available',
      );
    }

    try {
      final purchaseParam = PurchaseParam(productDetails: product!.productDetails);

      bool success;
      if (tier == PurchaseTier.familyUnlock) {
        success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }

      if (!success) {
        return PurchaseResult(
          status: FamQuestPurchaseStatus.error,
          tier: tier,
          error: 'Failed to initiate',
        );
      }

      return PurchaseResult(
        status: FamQuestPurchaseStatus.pending,
        tier: tier,
        needsVerification: true,
      );
    } catch (e) {
      return PurchaseResult(
        status: FamQuestPurchaseStatus.error,
        tier: tier,
        error: e.toString(),
      );
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final pd in purchaseDetailsList) {
      _handlePurchaseDetails(pd);
    }
  }

  Future<void> _handlePurchaseDetails(PurchaseDetails pd) async {
    final tier = ProductIds.getTierFromProductId(pd.productID);

    switch (pd.status) {
      case PurchaseStatus.pending:
        _purchaseStateController.add(PurchaseResult(
          status: FamQuestPurchaseStatus.pending,
          tier: tier,
          purchaseDetails: pd,
        ));
        break;

      case PurchaseStatus.purchased:
        final verified = await _verifyPurchase(pd);
        if (verified) {
          _purchaseStateController.add(PurchaseResult(
            status: FamQuestPurchaseStatus.verified,
            tier: tier,
            purchaseDetails: pd,
          ));
          await fetchSubscriptionStatus();
        } else {
          _purchaseStateController.add(PurchaseResult(
            status: FamQuestPurchaseStatus.error,
            tier: tier,
            error: 'Verification failed',
            purchaseDetails: pd,
          ));
        }

        if (pd.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(pd);
        }
        break;

      case PurchaseStatus.error:
        _purchaseStateController.add(PurchaseResult(
          status: FamQuestPurchaseStatus.error,
          tier: tier,
          error: pd.error?.message,
          purchaseDetails: pd,
        ));

        if (pd.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(pd);
        }
        break;

      case PurchaseStatus.restored:
        final verified = await _verifyPurchase(pd);
        if (verified) {
          _purchaseStateController.add(PurchaseResult(
            status: FamQuestPurchaseStatus.restored,
            tier: tier,
            purchaseDetails: pd,
          ));
          await fetchSubscriptionStatus();
        }

        if (pd.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(pd);
        }
        break;

      case PurchaseStatus.canceled:
        _purchaseStateController.add(PurchaseResult(
          status: FamQuestPurchaseStatus.canceled,
          tier: tier,
          purchaseDetails: pd,
        ));
        break;
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails pd) async {
    try {
      String receipt;
      String platform;

      if (Platform.isIOS) {
        platform = 'ios';
        final iosPd = pd as AppStorePurchaseDetails;
        receipt = iosPd.verificationData.serverVerificationData;
      } else if (Platform.isAndroid) {
        platform = 'android';
        final androidPd = pd as GooglePlayPurchaseDetails;
        receipt = androidPd.verificationData.serverVerificationData;
      } else {
        return false;
      }

      final response = await ApiClient.instance.verifyPurchaseReceipt(
        productId: pd.productID,
        transactionId: pd.purchaseID ?? '',
        receipt: receipt,
        platform: platform,
      );

      return response['is_valid'] == true;
    } catch (e) {
      debugPrint('[PURCHASE] Verification error: $e');
      return false;
    }
  }

  Future<PurchaseResult> restorePurchases() async {
    if (!_isAvailable) {
      return PurchaseResult(
        status: FamQuestPurchaseStatus.error,
        error: 'Store not available',
      );
    }

    try {
      // Restore purchases through the main API (works for both iOS and Android)
      await _inAppPurchase.restorePurchases();

      await fetchSubscriptionStatus();

      return PurchaseResult(
        status: FamQuestPurchaseStatus.restored,
      );
    } catch (e) {
      return PurchaseResult(
        status: FamQuestPurchaseStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> fetchSubscriptionStatus() async {
    try {
      final response = await ApiClient.instance.getSubscriptionStatus();
      _currentSubscription = SubscriptionStatus.fromJson(response);
      _subscriptionController.add(_currentSubscription!);
    } catch (e) {
      debugPrint('[PURCHASE] Fetch status error: $e');
    }
  }

  bool get hasPremium => _currentSubscription?.isPremium ?? false;
  bool get hasFamilyUnlock => _currentSubscription?.hasFamilyUnlock ?? false;
  bool get hasNoAds => _currentSubscription?.hasNoAds ?? false;
  bool get hasUnlimitedAI => _currentSubscription?.hasUnlimitedAI ?? false;

  PurchaseProduct? getProduct(PurchaseTier tier) => _products[tier.id];

  void dispose() {
    _subscription.cancel();
    _purchaseStateController.close();
    _subscriptionController.close();
  }
}
