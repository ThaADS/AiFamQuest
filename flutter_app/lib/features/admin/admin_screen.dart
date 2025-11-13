import 'package:flutter/material.dart';
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(leading: Icon(Icons.card_giftcard), title: Text('Beloningen beheren'), subtitle: Text('Toevoegen/aanpassen/kosten')),
        ListTile(leading: Icon(Icons.list_alt), title: Text('Taak-sjablonen'), subtitle: Text('Sets voor dagelijks/wekelijkse taken')),
        ListTile(leading: Icon(Icons.palette), title: Text('Thema’s & taal per profiel'), subtitle: Text('Cartoony/Minimal/Classy/Dark + NL/EN/…')),
      ],
    );
  }
}
