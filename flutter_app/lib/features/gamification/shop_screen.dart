import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../core/supabase.dart';
import '../../core/app_logger.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  List<dynamic> items = [];
  bool busy = false;
  int userPoints = 0;

  // Mocha Mousse color scheme
  static const mochaBrown = Color(0xFF6B4423);
  static const lightMocha = Color(0xFFB08968);
  static const cream = Color(0xFFF5EBE0);
  static const darkMocha = Color(0xFF3D2817);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      items = await ApiClient.instance.listRewards();
      await _loadUserPoints();
    } finally {
      setState(() => busy = false);
    }
  }

  Future<void> _loadUserPoints() async {
    try {
      final user = currentUser;
      if (user == null) return;

      // Get user's total points from points_ledger
      final result = await supabase
          .from('points_ledger')
          .select('delta')
          .eq('user_id', user.id);

      int total = 0;
      for (var row in result) {
        total += (row['delta'] as int);
      }

      if (mounted) {
        setState(() => userPoints = total);
      }
    } catch (e) {
      AppLogger.debug('[SHOP] Error loading points: $e');
    }
  }

  Future<void> _purchaseItem(Map<String, dynamic> reward) async {
    final cost = reward['cost'] as int;
    final name = reward['name'] as String;

    // Check if user has enough points
    if (userPoints < cost) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Niet genoeg punten! Je hebt $userPoints punten, maar dit kost $cost punten.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cream,
        title: const Text(
          'Bevestig aankoop',
          style: TextStyle(color: darkMocha, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wil je "$name" kopen?',
              style: const TextStyle(color: darkMocha, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: mochaBrown.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Kosten:', style: TextStyle(color: darkMocha, fontWeight: FontWeight.w600)),
                      Text('$cost punten', style: const TextStyle(color: mochaBrown, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Huidige saldo:', style: TextStyle(color: darkMocha)),
                      Text('$userPoints punten', style: const TextStyle(color: darkMocha)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Nieuw saldo:', style: TextStyle(color: darkMocha, fontWeight: FontWeight.w600)),
                      Text(
                        '${userPoints - cost} punten',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuleren', style: TextStyle(color: Colors.grey.shade600)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: mochaBrown),
            child: const Text('Kopen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Process purchase
    try {
      final user = currentUser;
      if (user == null) return;

      // Get user's family_id
      final userData = await supabase
          .from('users')
          .select('family_id')
          .eq('id', user.id)
          .single();

      final familyId = userData['family_id'] as String;

      // Deduct points via points_ledger (negative delta)
      await supabase.from('points_ledger').insert({
        'user_id': user.id,
        'family_id': familyId,
        'delta': -cost,
        'reason': 'Gekocht: $name',
        'task_id': null,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Reload points and show success
      await _loadUserPoints();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Je hebt "$name" gekocht! -$cost punten',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      AppLogger.debug('[SHOP] Error purchasing item: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fout bij aankoop: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: mochaBrown,
        foregroundColor: Colors.white,
        title: const Text('Winkel'),
        elevation: 0,
        actions: [
          // Points balance display
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  '$userPoints punten',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 80, color: lightMocha),
                      SizedBox(height: 16),
                      Text(
                        'Geen beloningen beschikbaar',
                        style: TextStyle(
                          fontSize: 20,
                          color: darkMocha,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Vraag je ouders om beloningen toe te voegen!',
                        style: TextStyle(color: mochaBrown),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final r = items[i];
                      final cost = r['cost'] as int;
                      final name = r['name'] as String? ?? 'Onbekend';
                      final desc = r['desc'] as String? ?? '';
                      final canAfford = userPoints >= cost;

                      return Card(
                        elevation: 2,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: canAfford ? mochaBrown.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: canAfford
                                          ? mochaBrown.withValues(alpha: 0.1)
                                          : Colors.grey.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.star,
                                      color: canAfford ? Colors.amber : Colors.grey,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: darkMocha,
                                          ),
                                        ),
                                        if (desc.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            desc,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: mochaBrown,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: lightMocha.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.stars, color: Colors.amber, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$cost punten',
                                          style: const TextStyle(
                                            color: darkMocha,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: canAfford ? () => _purchaseItem(r) : null,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: canAfford ? mochaBrown : Colors.grey,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    ),
                                    icon: Icon(canAfford ? Icons.shopping_cart : Icons.lock, size: 18),
                                    label: Text(canAfford ? 'Kopen' : 'Te duur'),
                                  ),
                                ],
                              ),
                              if (!canAfford) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline, size: 18, color: Colors.orange),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Je hebt nog ${cost - userPoints} punten nodig',
                                          style: TextStyle(
                                            color: Colors.orange.shade700,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
