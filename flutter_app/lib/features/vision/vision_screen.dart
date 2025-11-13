import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../api/client.dart';

class VisionScreen extends StatefulWidget {
  const VisionScreen({super.key});
  @override
  State<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends State<VisionScreen> {
  String? imageUrl;
  List<dynamic> tips = [];
  bool busy = false;
  final desc = TextEditingController(text: 'Badkamer met kalkaanslag en natte vloer');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: desc, decoration: const InputDecoration(labelText: 'Omschrijving (optioneel)')),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(onPressed: busy?null:() async {
                final picker = ImagePicker();
                final x = await picker.pickImage(source: ImageSource.camera);
                if (x == null) return;
                setState(()=>busy=true);
                final bytes = await x.readAsBytes();
                final res = await ApiClient.instance.uploadVision(x.name, bytes, description: desc.text);
                setState(() { imageUrl = res['url']; tips = (res['tips']?['tips'] ?? []) as List; busy=false; });
              }, child: const Text('Maak foto')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: busy?null:() async {
                final picker = ImagePicker();
                final x = await picker.pickImage(source: ImageSource.gallery);
                if (x == null) return;
                setState(()=>busy=true);
                final bytes = await x.readAsBytes();
                final res = await ApiClient.instance.uploadVision(x.name, bytes, description: desc.text);
                setState(() { imageUrl = res['url']; tips = (res['tips']?['tips'] ?? []) as List; busy=false; });
              }, child: const Text('Kies uit galerij')),
            ],
          ),
          const SizedBox(height: 16),
          if (imageUrl != null) Image.network(imageUrl!, height: 180, fit: BoxFit.cover),
          const SizedBox(height: 12),
          const Text('Schoonmaaktips:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...tips.map((t)=>ListTile(leading: const Icon(Icons.lightbulb), title: Text('$t'))),
          if (busy) const Center(child: CircularProgressIndicator())
        ],
      ),
    );
  }
}
