import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../vision/vision_screen.dart';
import '../gamification/shop_screen.dart';
import '../admin/admin_screen.dart';
import '../kiosk/kiosk_screen.dart';
import '../voice/voice_task.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> tasks = [];
  bool busy = false;
  int index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(()=>busy=true);
    try {
      await ApiClient.instance.flushQueue();
      tasks = await ApiClient.instance.listTasks();
    } finally { setState(()=>busy=false); }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      busy ? const Center(child: CircularProgressIndicator()) :
        ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (ctx, i) {
            final t = tasks[i];
            return ListTile(
              leading: const Icon(Icons.check_box_outline_blank),
              title: Text(t['title'] ?? ''),
              subtitle: Text(t['due'] ?? 'vandaag'),
            );
          },
        ),
      const VisionScreen(),
      const ShopScreen(),
      const AdminScreen(),
      const KioskScreen(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('FamQuest v9'), actions: [
        IconButton(
          onPressed: ()=>Navigator.pushNamed(context, '/calendar'),
          icon: const Icon(Icons.calendar_month),
          tooltip: 'Calendar',
        ),
        IconButton(onPressed: ()=>Navigator.of(context).push(MaterialPageRoute(builder: (_)=>const VoiceTaskScreen())), icon: const Icon(Icons.mic))
      ]),
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i)=>setState(()=>index=i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Vision'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'Shop'),
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Ouder'),
          BottomNavigationBarItem(icon: Icon(Icons.fullscreen), label: 'Kiosk'),
        ],
      ),
      floatingActionButton: index==0 ? FloatingActionButton(
        onPressed: () async {
          await ApiClient.instance.createTask({'title':'Nieuw: kamer opruimen','assignees':[],'points':10});
          await _load();
        },
        child: const Icon(Icons.add),
      ): null,
    );
  }
}
