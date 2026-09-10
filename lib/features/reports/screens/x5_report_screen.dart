import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/crystal_report_service.dart';

class X5ReportScreen extends StatefulWidget {
  const X5ReportScreen({super.key});

  @override
  State<X5ReportScreen> createState() => _X5ReportScreenState();
}

class _X5ReportScreenState extends State<X5ReportScreen> {
  final CrystalReportService _reportService = CrystalReportService();
  List<File> _downloadedArchives = [];
  Directory? _workDir;
  DateTime? _sourceArchiveDate;
  List<FileSystemEntity> _workFiles = [];
  List<File> _selectedFiles = [];
  bool _isLoading = false;
  String _loadingMessage = 'Загрузка...';

  @override
  void initState() {
    super.initState();
    _loadDownloadedArchives();
  }

  @override
  void dispose() {
    _cleanupWorkDir();
    super.dispose();
  }

  Future<void> _cleanupWorkDir() async {
    if (_workDir != null && await _workDir!.exists()) {
      await _workDir!.delete(recursive: true);
    }
  }

  Future<void> _loadDownloadedArchives() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Поиск архивов...';
    });
    try {
      final archives = await _reportService.getDownloadedArchives();
      setState(() {
        _downloadedArchives = archives;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectArchive(File zipFile) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Распаковка архива...';
    });
    try {
      final date = _reportService.parseDateFromFileName(zipFile.path);
      final dir = await _reportService.extractZipToWorkDir(zipFile);
      setState(() {
        _workDir = dir;
        _sourceArchiveDate = date;
      });
      await _refreshWorkFiles();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка распаковки: $e')));
      }
    }
  }

  Future<void> _refreshWorkFiles() async {
    if (_workDir == null) return;
    setState(() => _isLoading = true);
    try {
      final entities = await _workDir!.list().toList();
      // Sort files to keep them consistent
      entities.sort((a, b) => a.path.compareTo(b.path));
      setState(() {
        _workFiles = entities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(File file) {
    setState(() {
      if (_selectedFiles.contains(file)) {
        _selectedFiles.remove(file);
      } else {
        _selectedFiles.add(file);
      }
    });
  }

  Future<void> _createPdfFromSelected() async {
    if (_selectedFiles.isEmpty || _workDir == null) return;

    final nameController = TextEditingController(
      text: 'Doc_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
    );

    final String? pdfName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать PDF'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Имя PDF файла'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, nameController.text), child: const Text('Создать')),
        ],
      ),
    );

    if (pdfName != null && pdfName.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _loadingMessage = 'Создание PDF...';
      });
      try {
        await _reportService.generatePdf(_selectedFiles, pdfName, outputDir: _workDir);
        setState(() {
          _selectedFiles.clear();
        });
        await _refreshWorkFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF создан и добавлен в папку')));
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка PDF: $e')));
      }
    }
  }

  Future<void> _deleteSelectedFiles() async {
    if (_selectedFiles.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить выбранное?'),
        content: Text('Будет удалено ${_selectedFiles.length} файлов.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        for (var file in _selectedFiles) {
          if (await file.exists()) {
            await file.delete();
          }
        }
        setState(() => _selectedFiles.clear());
        await _refreshWorkFiles();
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
      }
    }
  }

  Future<void> _createFinalArchive() async {
    if (_workDir == null) return;

    final nameController = TextEditingController(
      text: 'X5_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
    );

    final String? archiveName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать итоговый архив'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Имя архива'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, nameController.text), child: const Text('Создать')),
        ],
      ),
    );

    if (archiveName != null && archiveName.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _loadingMessage = 'Сборка архива...';
      });
      try {
        final path = await _reportService.zipDirectory(_workDir!, archiveName, logicalDate: _sourceArchiveDate);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Архив создан: $path')));
          Navigator.pop(context);
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка архивации: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_workDir == null ? 'Отчет X5: Выбор архива' : 'Рабочая область X5'),
        leading: _workDir != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _cleanupWorkDir();
                  setState(() {
                    _workDir = null;
                    _selectedFiles.clear();
                  });
                },
              )
            : null,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_loadingMessage),
                ],
              ),
            )
          : _workDir == null
              ? _buildArchivePicker()
              : _buildWorkspace(),
    );
  }

  Widget _buildArchivePicker() {
    if (_downloadedArchives.isEmpty) {
      return const Center(
        child: Text('В папке "Загрузки" нет ZIP-архивов'),
      );
    }
    return ListView.builder(
      itemCount: _downloadedArchives.length,
      itemBuilder: (context, index) {
        final file = _downloadedArchives[index];
        final fileName = file.path.split(Platform.pathSeparator).last;
        return ListTile(
          leading: const Icon(Icons.archive, color: Colors.amber),
          title: Text(fileName),
          subtitle: Text('${(file.lengthSync() / 1024).toStringAsFixed(1)} KB'),
          onTap: () => _selectArchive(file),
        );
      },
    );
  }

  Widget _buildWorkspace() {
    final filteredFiles = _workFiles.whereType<File>().toList();

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: filteredFiles.length,
            itemBuilder: (context, index) {
              final file = filteredFiles[index];
              final fileName = file.path.split(Platform.pathSeparator).last;
              final isPdf = fileName.toLowerCase().endsWith('.pdf');
              final isImage = ['.jpg', '.jpeg', '.png'].any((ext) => fileName.toLowerCase().endsWith(ext));
              
              final selectionIndex = _selectedFiles.indexOf(file);
              final isSelected = selectionIndex != -1;

              return GestureDetector(
                onTap: () => _toggleSelection(file),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isImage)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(file, fit: BoxFit.cover),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: isPdf ? Colors.red[50] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file, color: isPdf ? Colors.red : Colors.grey, size: 40),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
                            ),
                          ],
                        ),
                      ),
                    if (isSelected)
                      Container(
                        color: Colors.black45,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                            child: Text('${selectionIndex + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        _buildWorkspaceActions(),
      ],
    );
  }

  Widget _buildWorkspaceActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _createPdfFromSelected,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Создать PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _deleteSelectedFiles,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Удалить'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        foregroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ElevatedButton.icon(
            onPressed: _createFinalArchive,
            icon: const Icon(Icons.archive),
            label: const Text('Создать итоговый архив'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
