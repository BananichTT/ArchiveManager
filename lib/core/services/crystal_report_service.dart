import 'dart:io';
import 'package:photo_manager/photo_manager.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CrystalReportService {
  
  Future<List<AssetEntity>> getMediaByDate(DateTime date) async {
    final DateTime start = DateTime(date.year, date.month, date.day);
    final DateTime end = start.add(const Duration(days: 1));

    final FilterOptionGroup filter = FilterOptionGroup(
      createTimeCond: DateTimeCond(
        min: start,
        max: end,
      ),
      orders: [
        const OrderOption(type: OrderOptionType.createDate, asc: false),
      ],
    );

    // Get only images
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: filter,
    );

    List<AssetEntity> allAssets = [];
    for (var path in paths) {
      // "Recent" path usually contains all assets, but to be safe and cross-album, 
      // we check all paths if needed, though filtered by date usually returns what we want globally
      if (path.isAll) {
         final assets = await path.getAssetListRange(start: 0, end: 1000);
         allAssets.addAll(assets);
         break; // Found the "All" path, no need to check others for global search
      }
    }
    
    return allAssets;
  }

  Future<String> createArchive(List<File> files, String archiveName) async {
    final encoder = ZipFileEncoder();
    final directory = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${directory.path}/reports');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }

    final zipPath = '${reportsDir.path}/$archiveName.zip';
    encoder.create(zipPath);

    for (var file in files) {
      encoder.addFile(file);
    }
    encoder.close();

    return zipPath;
  }

  Future<List<File>> getArchives() async {
    final directory = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${directory.path}/reports');
    if (!await reportsDir.exists()) return [];

    final List<FileSystemEntity> entities = await reportsDir.list().toList();
    return entities
        .whereType<File>()
        .where((file) => p.extension(file.path) == '.zip')
        .toList();
  }

  Future<void> deleteArchive(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
