import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../core/services/crystal_report_service.dart';

class CrystalReportScreen extends StatefulWidget {
  const CrystalReportScreen({super.key});

  @override
  State<CrystalReportScreen> createState() => _CrystalReportScreenState();
}

class _CrystalReportScreenState extends State<CrystalReportScreen> {
  final CrystalReportService _reportService = CrystalReportService();
  DateTime _selectedDate = DateTime.now();
  List<AssetEntity> _assets = [];
  
  // Selection logic for the grid (numbered)
  List<AssetEntity> _selectedAssets = [];
  
  // Staged files for the final archive
  List<AssetEntity> _finalStagedAssets = [];
  List<File> _generatedPdfs = [];
  
  bool _showTempFolder = false;
  bool _isLoading = false;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _requestAssetsPermission();
  }

  Future<void> _requestAssetsPermission() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      setState(() {
        _hasPermission = true;
      });
      _loadAssets();
    } else {
      setState(() {
        _hasPermission = false;
      });
      if (mounted) {
        PhotoManager.openSetting();
      }
    }
  }

  Future<void> _loadAssets() async {
    if (!_hasPermission) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final assets = await _reportService.getMediaByDate(_selectedDate);
      setState(() {
        _assets = assets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при загрузке фото: $e')),
        );
      }
    }
  }

  void _toggleSelection(AssetEntity asset) {
    setState(() {
      if (_selectedAssets.contains(asset)) {
        _selectedAssets.remove(asset);
      } else {
        _selectedAssets.add(asset);
      }
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadAssets();
    }
  }

  void _moveToFinalStaging() {
    setState(() {
      _finalStagedAssets.addAll(_selectedAssets);
      _selectedAssets.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Фото добавлены во временную папку')),
    );
  }

  Future<void> _createPdfFromSelected() async {
    if (_selectedAssets.isEmpty) return;

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
      setState(() => _isLoading = true);
      try {
        List<File> files = [];
        for (var asset in _selectedAssets) {
          final f = await asset.file;
          if (f != null) files.add(f);
        }
        
        final pdfFile = await _reportService.generatePdf(files, pdfName);
        setState(() {
          _generatedPdfs.add(pdfFile);
          _selectedAssets.clear();
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF создан и добавлен во временную папку')),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка PDF: $e')));
      }
    }
  }

  Future<void> _createArchive() async {
    if (_finalStagedAssets.isEmpty && _generatedPdfs.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final nameController = TextEditingController(
      text: 'Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
    );

    final String? archiveName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать архив'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Имя архива'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Создать'),
          ),
        ],
      ),
    );

    if (archiveName != null && archiveName.isNotEmpty) {
      try {
        List<File> filesToArchive = [..._generatedPdfs];
        for (var asset in _finalStagedAssets) {
          final file = await asset.file;
          if (file != null) {
            filesToArchive.add(file);
          }
        }

        if (filesToArchive.isEmpty) {
          throw Exception("Нет файлов для архивации");
        }

        final path = await _reportService.createArchive(filesToArchive, archiveName);
        setState(() {
          _finalStagedAssets.clear();
          _generatedPdfs.clear();
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Архив создан: $path')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка при создании архива: $e')),
          );
        }
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчет Кристалл'),
      ),
      body: !_hasPermission 
          ? _buildPermissionRequestView()
          : Column(
              children: [
                _buildDateSelector(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _showTempFolder
                          ? _buildTempFolderView()
                          : _buildGalleryView(),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildPermissionRequestView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Приложению нужен доступ к вашим фотографиям'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _requestAssetsPermission,
            child: const Text('Предоставить доступ'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.deepPurple.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Дата: ${DateFormat('dd.MM.yyyy').format(_selectedDate)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ElevatedButton.icon(
            onPressed: _selectDate,
            icon: const Icon(Icons.calendar_today),
            label: const Text('Выбрать дату'),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryView() {
    return Column(
      children: [
        Expanded(child: _buildPhotoGridView()),
        if (_selectedAssets.isNotEmpty) _buildSelectionActions(),
      ],
    );
  }

  Widget _buildSelectionActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _createPdfFromSelected,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Создать PDF'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _moveToFinalStaging,
              icon: const Icon(Icons.add_to_photos),
              label: const Text('В архив'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple[50], foregroundColor: Colors.deepPurple),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGridView() {
    if (_assets.isEmpty) {
      return const Center(
        child: Text('Нет фотографий за эту дату'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _assets.length,
      itemBuilder: (context, index) {
        final asset = _assets[index];
        final selectionIndex = _selectedAssets.indexOf(asset);
        final isSelected = selectionIndex != -1;
        
        return GestureDetector(
          onTap: () => _toggleSelection(asset),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Uint8List?>(
                future: asset.thumbnailData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
              if (isSelected)
                Container(
                  color: Colors.black45,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.deepPurple,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${selectionIndex + 1}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTempFolderView() {
    if (_finalStagedAssets.isEmpty && _generatedPdfs.isEmpty) {
      return const Center(
        child: Text('Временная папка пуста.\nДобавьте файлы из галереи.'),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              if (_generatedPdfs.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('PDF ФАЙЛЫ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                ),
                ..._generatedPdfs.map((file) => ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(file.path.split('/').last),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _generatedPdfs.remove(file)),
                  ),
                )),
              ],
              if (_finalStagedAssets.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('ФОТОГРАФИИ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                ),
                ..._finalStagedAssets.map((asset) => ListTile(
                  leading: FutureBuilder<Uint8List?>(
                    future: asset.thumbnailData,
                    builder: (context, snapshot) {
                      if (snapshot.data != null) return Image.memory(snapshot.data!, width: 50, height: 50, fit: BoxFit.cover);
                      return const SizedBox(width: 50, height: 50);
                    },
                  ),
                  title: Text(asset.title ?? 'Image'),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() => _finalStagedAssets.remove(asset)),
                  ),
                )),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _createArchive,
            icon: const Icon(Icons.archive),
            label: const Text('Создать итоговый архив'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final totalItems = _finalStagedAssets.length + _generatedPdfs.length;
    return BottomNavigationBar(
      currentIndex: _showTempFolder ? 1 : 0,
      onTap: (index) {
        setState(() {
          _showTempFolder = index == 1;
        });
      },
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.photo_library),
          label: 'Галерея',
        ),
        BottomNavigationBarItem(
          icon: Stack(
            children: [
              const Icon(Icons.folder_special),
              if (totalItems > 0)
                Positioned(
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text('$totalItems', style: const TextStyle(color: Colors.white, fontSize: 8), textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
          label: 'Временная папка',
        ),
      ],
    );
  }
}
