import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
class OfflineQueue {
  static final OfflineQueue instance = OfflineQueue._();
  OfflineQueue._();
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/queue.json');
  }
  Future<void> enqueue(Map<String, dynamic> op) async {
    final f = await _file();
    List list = [];
    if (await f.exists()) { list = jsonDecode(await f.readAsString()); }
    list.add(op);
    await f.writeAsString(jsonEncode(list));
  }
  Future<List> load() async {
    final f = await _file();
    if (await f.exists()) return jsonDecode(await f.readAsString());
    return [];
  }
  Future<void> clear() async {
    final f = await _file();
    if (await f.exists()) await f.writeAsString('[]');
  }
}
