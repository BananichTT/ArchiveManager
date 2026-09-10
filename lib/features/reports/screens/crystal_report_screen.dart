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
  
  // Cache for thumbnails to prevent flickering
  final Map<String, Uint8List> _thumbnailCache = {};
  
  // Selection logic for the gallery grid (numbered)
  List<AssetEntity> _selectedAssets = [];
  
  // Staged files for the final archive
  List<AssetEntity> _finalStagedAssets = [];
  List<File> _generatedPdfs = [];
  
  // Selection logic for the temporary folder (staging)
  final Set<dynamic> _tempFolderSelection = {}; // Can contain AssetEntity or File (PDF)

  bool _showTempFolder = false;
  bool _isLoading = false;
  String _loadingMessage = 'Загрузка...';
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
      _loadingMessage = 'Загрузка фотографий...';
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
  
  void _toggleTempFolderSelection(dynamic item) {
    setState(() {
      if (_tempFolderSelection.contains(item)) {
        _tempFolderSelection.remove(item);
      } else {
        _tempFolderSelection.add(item);
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
        _thumbnailCache.clear(); // Clear cache for new date
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
      setState(() {
        _isLoading = true;
        _loadingMessage = 'Сжатие и создание PDF...';
      });
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

  Future<void> _deleteSelectedFromStaging() async {
    if (_tempFolderSelection.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить из папки?'),
        content: Text('Будет удалено ${_tempFolderSelection.length} объектов из временной папки.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        for (var item in _tempFolderSelection) {
          if (item is AssetEntity) {
            _finalStagedAssets.remove(item);
          } else if (item is File) {
            _generatedPdfs.remove(item);
          }
        }
        _tempFolderSelection.clear();
      });
    }
  }

  Future<void> _createArchive() async {
    if (_finalStagedAssets.isEmpty && _generatedPdfs.isEmpty) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Сжатие и архивация...';
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
        final now = DateTime.now();
        final logicalDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          now.hour,
          now.minute,
          now.second,
        );

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

        final path = await _reportService.createArchive(filesToArchive, archiveName, logicalDate: logicalDate);
        setState(() {
          _finalStagedAssets.clear();
          _generatedPdfs.clear();
          _tempFolderSelection.clear();
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
              _buildCachedThumbnail(asset),
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

  Widget _buildCachedThumbnail(AssetEntity asset) {
    if (_thumbnailCache.containsKey(asset.id)) {
      return Image.memory(
        _thumbnailCache[asset.id]!,
        fit: BoxFit.cover,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          _thumbnailCache[asset.id] = snapshot.data!;
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildTempFolderView() {
    final allStagedItems = [..._generatedPdfs, ..._finalStagedAssets];
    
    if (allStagedItems.isEmpty) {
      return const Center(
        child: Text('Временная папка пуста.\nДобавьте файлы из галереи.'),
      );
    }

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
            itemCount: allStagedItems.length,
            itemBuilder: (context, index) {
              final item = allStagedItems[index];
              final isSelected = _tempFolderSelection.contains(item);
              
              Widget content;
              if (item is File) {
                // PDF File
                content = Container(
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red[100]!),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.red, size: 40),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(item.path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
                      ),
                    ],
                  ),
                );
              } else {
                // AssetEntity (Photo)
                content = ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: _buildCachedThumbnail(item as AssetEntity),
                );
              }

              return GestureDetector(
                onTap: () => _toggleTempFolderSelection(item),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    content,
                    if (isSelected)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: Icon(Icons.check_circle, color: Colors.green, size: 40),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        _buildTempFolderActions(),
      ],
    );
  }

  Widget _buildTempFolderActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_tempFolderSelection.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton.icon(
                onPressed: _deleteSelectedFromStaging,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Удалить из папки'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(45),
                  backgroundColor: Colors.grey[100],
                  foregroundColor: Colors.grey[700],
                ),
              ),
            ),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _createArchive,
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
