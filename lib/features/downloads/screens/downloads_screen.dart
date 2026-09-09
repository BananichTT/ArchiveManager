import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/services/file_storage_service.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final FileStorageService _storageService = FileStorageService();
  late StreamSubscription _intentDataStreamSubscription;
  List<File> _downloadedFiles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFiles();

    // Listen to sharing images coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      _handleSharedFiles(value);
    }, onError: (err) {
      debugPrint("getIntentDataStream error: $err");
    });

    // Get the images shared from outside the app while the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      _handleSharedFiles(value);
      ReceiveSharingIntent.instance.reset();
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });
    final files = await _storageService.getDownloadedFiles();
    // Sort by modification time to show newest first
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    setState(() {
      _downloadedFiles = files;
      _isLoading = false;
    });
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    for (var file in files) {
      await _storageService.saveFile(file.path);
    }
    
    await _loadFiles();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Загружено файлов: ${files.length}')),
      );
    }
  }

  Future<void> _deleteFile(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить файл?'),
        content: Text('Вы уверены, что хотите удалить ${file.path.split('/').last}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storageService.deleteFile(file);
      await _loadFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл удален')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Загрузки'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _downloadedFiles.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'Нет загруженных файлов.\n\nЧтобы добавить файл, выберите его в другом приложении (Галерея, Проводник) и нажмите "Поделиться", затем выберите Archive Manager.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _downloadedFiles.length,
                  itemBuilder: (context, index) {
                    final file = _downloadedFiles[index];
                    final fileName = file.path.split(Platform.pathSeparator).last;
                    final size = file.lengthSync();
                    final sizeStr = size < 1024 * 1024 
                        ? '${(size / 1024).toStringAsFixed(2)} KB'
                        : '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.insert_drive_file),
                        ),
                        title: Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(sizeStr),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteFile(file),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
