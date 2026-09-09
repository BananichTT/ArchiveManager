import 'package:flutter/material.dart';
import '../../../core/widgets/app_drawer.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчеты'),
      ),
      drawer: const AppDrawer(),
      body: const Center(
        child: Text('Экран отчетов'),
      ),
    );
  }
}
