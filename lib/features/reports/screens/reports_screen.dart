import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/services/crystal_report_service.dart';
import '../models/report_model.dart';
import 'crystal_report_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final CrystalReportService _reportService = CrystalReportService();
  List<File> _archives = [];
  final Set<File> _selectedArchives = {};
  bool _isLoading = false;
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadArchives();
  }

  Future<void> _loadArchives() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final archives = await _reportService.getArchives();
      // Sort by modification date (newest first)
      archives.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      setState(() {
        _archives = archives;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(File file) {
    setState(() {
      if (_selectedArchives.contains(file)) {
        _selectedArchives.remove(file);
        if (_selectedArchives.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedArchives.add(file);
        _isSelectionMode = true;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedArchives.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _shareSelected() async {
    if (_selectedArchives.isEmpty) return;
    
    final xFiles = _selectedArchives.map((file) => XFile(file.path)).toList();
    await Share.shareXFiles(xFiles, text: 'Мои отчеты из Archive Manager');
    _exitSelectionMode();
  }

  Future<void> _deleteSelected() async {
    if (_selectedArchives.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить выбранное?'),
        content: Text('Будет удалено ${_selectedArchives.length} архивов.'),
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
      setState(() {
        _isLoading = true;
      });
      for (var file in _selectedArchives) {
        await _reportService.deleteArchive(file);
      }
      _exitSelectionMode();
      await _loadArchives();
    }
  }

  void _showReportTypeSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Выберите тип отчета',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.blue),
                title: Text(ReportType.x5.displayName),
                onTap: () {
                  Navigator.pop(context);
                  _handleReportSelection(context, ReportType.x5);
                },
              ),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.green),
                title: Text(ReportType.crystal.displayName),
                onTap: () {
                  Navigator.pop(context);
                  _handleReportSelection(context, ReportType.crystal);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleReportSelection(BuildContext context, ReportType type) {
    if (type == ReportType.crystal) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CrystalReportScreen()),
      ).then((_) => _loadArchives());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Выбран: ${type.displayName}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? 'Выбрано: ${_selectedArchives.length}' : 'Отчеты'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareSelected,
              tooltip: 'Поделиться',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelected,
              tooltip: 'Удалить',
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadArchives,
              tooltip: 'Обновить',
            ),
        ],
      ),
      drawer: _isSelectionMode ? null : const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _archives.isEmpty
              ? const Center(
                  child: Text('У вас пока нет созданных отчетов'),
                )
              : ListView.builder(
                  itemCount: _archives.length,
                  itemBuilder: (context, index) {
                    final file = _archives[index];
                    final isSelected = _selectedArchives.contains(file);
                    final fileName = file.path.split('/').last;
                    final stat = file.statSync();
                    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(stat.modified);
                    final size = (file.lengthSync() / 1024).toStringAsFixed(1) + ' KB';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      color: isSelected ? Colors.deepPurple.withOpacity(0.1) : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? Colors.deepPurple : Colors.grey[200],
                          child: Icon(
                            isSelected ? Icons.check : Icons.archive,
                            color: isSelected ? Colors.white : Colors.deepPurple,
                          ),
                        ),
                        title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$dateStr | $size'),
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(file);
                          } else {
                            // Single tap action (maybe preview or share single?)
                            _toggleSelection(file);
                          }
                        },
                        onLongPress: () => _toggleSelection(file),
                      ),
                    );
                  },
                ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => _showReportTypeSelection(context),
              child: const Icon(Icons.add),
            ),
    );
  }
}
