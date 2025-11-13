import 'package:flutter/material.dart';
import '../../api/client.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  List<dynamic> items = [];
  bool busy = false;
  @override
  void initState(){ super.initState(); _load(); }
  Future<void> _load() async {
    setState(()=>busy=true);
    try { items = await ApiClient.instance.listRewards(); }
    finally { setState(()=>busy=false); }
  }
  @override
  Widget build(BuildContext context) {
    if (busy) return const Center(child: CircularProgressIndicator());
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (ctx,i){
        final r = items[i];
        return Card(child: ListTile(
          leading: const Icon(Icons.star),
          title: Text(r['name'] ?? ''),
          subtitle: Text('Kosten: ${r['cost']} ptn'),
          trailing: FilledButton(onPressed: (){}, child: const Text('Sparen')),
        ));
      },
    );
  }
}
