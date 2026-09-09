import 'package:flutter/material.dart';
import '../../../core/widgets/app_drawer.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Карта'),
      ),
      drawer: const AppDrawer(),
      body: const Center(
        child: Text('Экран карты'),
      ),
    );
  }
}
