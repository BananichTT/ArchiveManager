import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/widgets/app_drawer.dart';
import '../models/store_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<StoreItem> _stores = [];
  bool _isLoading = false;

  void _clearStores() {
    setState(() {
      _stores = [];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Список очищен')),
    );
  }

  Future<void> _pickAndLoadFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      // result в данном случае — это List<PlatformFile>?
      if (result != null && result.isNotEmpty && result.single.path != null) {
        setState(() {
          _isLoading = true;
        });

        final file = File(result.single.path!);
        final content = await file.readAsString();
        final List<dynamic> jsonData = jsonDecode(content);

        setState(() {
          _stores = jsonData.map((item) => StoreItem.fromJson(item)).toList();
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Загружено объектов: ${_stores.length}')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при загрузке файла: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Главная'),
        actions: [
          if (_stores.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Очистить список',
              onPressed: _isLoading ? null : _clearStores,
            ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Загрузить список',
            onPressed: _isLoading ? null : _pickAndLoadFile,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stores.isEmpty
          ? const Center(
        child: Text('Нажмите на иконку сверху, чтобы загрузить список объектов'),
      )
          : ListView.builder(
        itemCount: _stores.length,
        itemBuilder: (context, index) {
          final item = _stores.length > index ? _stores[index] : null;
          if (item == null) return const SizedBox.shrink();

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.store),
              ),
              title: Text(
                item.storeName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(item.address),
              trailing: Text('#${item.storeNum}'),
            ),
          );
        },
      ),
    );
  }
}