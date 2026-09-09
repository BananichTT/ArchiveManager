import 'package:flutter/material.dart';
import '../../../core/widgets/app_drawer.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Загрузки'),
      ),
      drawer: const AppDrawer(),
      body: const Center(
        child: Text('Экран загрузок'),
      ),
    );
  }
}
