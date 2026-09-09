import 'package:flutter/material.dart';
import '../../../core/widgets/app_drawer.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      drawer: const AppDrawer(),
      body: const Center(
        child: Text('Экран настроек'),
      ),
    );
  }
}
