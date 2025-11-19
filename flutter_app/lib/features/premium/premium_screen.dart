/// Premium Subscription Screen for FamQuest
///
/// Displays purchase tiers with feature comparison:
/// - Free (current)
/// - Family Unlock (€19.99 one-time)
/// - Premium Monthly (€4.99/month)
/// - Premium Yearly (€49.99/year - save €10!)
///
/// Features:
/// - Feature comparison table
/// - Purchase buttons with loading states
/// - Restore purchases button
/// - Success/error handling
/// - Current subscription display

import 'package:flutter/material.dart';
import '../../models/purchase_models.dart';
import '../../services/purchase_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final _purchaseService = PurchaseService();
  bool _isLoading = true;
  bool _isRestoring = false;
  String? _errorMessage;
  PurchaseTier? _purchasingTier;

  @override
  void initState() {
    super.initState();
    _initializePurchases();
  }

  Future<void> _initializePurchases() async {
    setState(() => _isLoading = true);

    try {
      await _purchaseService.initialize();

      // Listen to purchase events
      _purchaseService.purchaseStream.listen((result) {
        if (!mounted) return;

        setState(() => _purchasingTier = null);

        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Aankoop geslaagd! Welkom bij ${result.tier?.displayName}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.pop(context, true); // Return to previous screen with success
        } else if (result.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fout: ${result.error ?? "Onbekende fout"}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (result.status == FamQuestPurchaseStatus.canceled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aankoop geannuleerd'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      });

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _handlePurchase(PurchaseTier tier) async {
    setState(() => _purchasingTier = tier);

    try {
      await _purchaseService.purchaseProduct(tier);
      // Result will come via stream
    } catch (e) {
      setState(() => _purchasingTier = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij aankoop: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isRestoring = true);

    try {
      final result = await _purchaseService.restorePurchases();

      if (mounted) {
        setState(() => _isRestoring = false);

        if (result.isSuccess || result.status == FamQuestPurchaseStatus.restored) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aankopen hersteld!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Geen eerdere aankopen gevonden'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRestoring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij herstellen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FamQuest Premium'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError(theme)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCurrentSubscription(theme),
                      const SizedBox(height: 24),
                      _buildTierCard(
                        theme,
                        PurchaseTier.free,
                        isCurrentTier: _purchaseService.currentSubscription?.activeTier == PurchaseTier.free,
                      ),
                      const SizedBox(height: 16),
                      _buildTierCard(
                        theme,
                        PurchaseTier.familyUnlock,
                        isCurrentTier: _purchaseService.currentSubscription?.activeTier == PurchaseTier.familyUnlock,
                        isPopular: false,
                      ),
                      const SizedBox(height: 16),
                      _buildTierCard(
                        theme,
                        PurchaseTier.premiumMonthly,
                        isCurrentTier: _purchaseService.currentSubscription?.activeTier == PurchaseTier.premiumMonthly,
                        isPopular: false,
                      ),
                      const SizedBox(height: 16),
                      _buildTierCard(
                        theme,
                        PurchaseTier.premiumYearly,
                        isCurrentTier: _purchaseService.currentSubscription?.activeTier == PurchaseTier.premiumYearly,
                        isPopular: true,
                      ),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: _isRestoring ? null : _handleRestore,
                        icon: _isRestoring
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.restore),
                        label: Text(_isRestoring ? 'Herstellen...' : 'Aankopen herstellen'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aankopen zijn gekoppeld aan je Apple ID of Google-account en werken op al je apparaten.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Fout bij laden van aankopen',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Onbekende fout',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _initializePurchases,
              icon: const Icon(Icons.refresh),
              label: const Text('Opnieuw proberen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSubscription(ThemeData theme) {
    final subscription = _purchaseService.currentSubscription;
    if (subscription == null || !subscription.isActive) {
      return const SizedBox.shrink();
    }

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Huidige abonnement',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subscription.displayText,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subscription.expiryDate != null) ...[
              const SizedBox(height: 8),
              Text(
                subscription.autoRenew
                    ? 'Verlengt automatisch op ${_formatDate(subscription.expiryDate!)}'
                    : 'Verloopt op ${_formatDate(subscription.expiryDate!)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              if (subscription.isExpiringSoon)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Nog ${subscription.daysUntilExpiry} dagen!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard(
    ThemeData theme,
    PurchaseTier tier, {
    bool isCurrentTier = false,
    bool isPopular = false,
  }) {
    final product = _purchaseService.getProduct(tier);
    final isPurchasing = _purchasingTier == tier;

    return Card(
      elevation: isPopular ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPopular
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isPopular)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'MEEST POPULAIR',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (isPopular) const SizedBox(height: 16),

            // Title and price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product?.title ?? tier.displayName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product?.description ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (tier != PurchaseTier.free) ...[
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        product?.price ?? '€${tier.price}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (product?.savingsText != null)
                        Text(
                          product!.savingsText!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Features list
            if (product != null && product.features.isNotEmpty) ...[
              ...product.features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feature,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 16),
            ],

            // Purchase button
            if (isCurrentTier)
              FilledButton.tonal(
                onPressed: null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Huidig abonnement'),
              )
            else if (tier == PurchaseTier.free)
              const SizedBox.shrink()
            else
              FilledButton(
                onPressed: isPurchasing ? null : () => _handlePurchase(tier),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: isPopular ? theme.colorScheme.primary : null,
                ),
                child: isPurchasing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        tier == PurchaseTier.familyUnlock
                            ? 'Eenmalig kopen'
                            : 'Abonneren',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}-${date.month}-${date.year}';
  }
}
