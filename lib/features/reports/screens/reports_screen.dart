import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/services/crystal_report_service.dart';
import '../models/report_model.dart';
import 'crystal_report_screen.dart';
import 'x5_report_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final CrystalReportService _reportService = CrystalReportService();
  
  // Flattened list for the UI: contains either DateTime (header) or File (item)
  List<dynamic> _uiItems = [];
  
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
      
      // Sort archives by modification date (newest first)
      archives.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      
      // Group and flatten
      final List<dynamic> items = [];
      DateTime? lastDate;
      
      for (var file in archives) {
        final modDate = file.lastModifiedSync();
        final dateOnly = DateTime(modDate.year, modDate.month, modDate.day);
        
        if (lastDate == null || dateOnly != lastDate) {
          items.add(dateOnly);
          lastDate = dateOnly;
        }
        items.add(file);
      }

      setState(() {
        _uiItems = items;
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
    } else if (type == ReportType.x5) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const X5ReportScreen()),
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
          : _uiItems.isEmpty
              ? const Center(
                  child: Text('У вас пока нет созданных отчетов'),
                )
              : ListView.builder(
                  itemCount: _uiItems.length,
                  itemBuilder: (context, index) {
                    final item = _uiItems[index];

                    if (item is DateTime) {
                      // Date Header
                      return _buildDateHeader(item);
                    } else if (item is File) {
                      // Archive Item
                      return _buildArchiveTile(item);
                    }
                    return const SizedBox.shrink();
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

  Widget _buildDateHeader(DateTime date) {
    String dateStr;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      dateStr = 'Сегодня';
    } else if (date == yesterday) {
      dateStr = 'Вчера';
    } else {
      dateStr = DateFormat('d MMMM yyyy', 'ru_RU').format(date);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        dateStr,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple.withOpacity(0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildArchiveTile(File file) {
    final isSelected = _selectedArchives.contains(file);
    final fileName = file.path.split('/').last;
    final stat = file.statSync();
    final timeStr = DateFormat('HH:mm').format(stat.modified);
    final size = (file.lengthSync() / 1024).toStringAsFixed(1) + ' KB';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
          ? BorderSide(color: Colors.deepPurple.withOpacity(0.5), width: 2)
          : BorderSide.none,
      ),
      color: isSelected ? Colors.deepPurple.withOpacity(0.05) : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isSelected ? Colors.deepPurple : Colors.deepPurple.withOpacity(0.1),
          child: Icon(
            isSelected ? Icons.check : Icons.archive_outlined,
            color: isSelected ? Colors.white : Colors.deepPurple,
          ),
        ),
        title: Text(
          fileName,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('$timeStr | $size', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(file);
          } else {
            _toggleSelection(file);
          }
        },
        onLongPress: () => _toggleSelection(file),
      ),
    );
  }
}
