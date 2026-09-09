import 'dart:io';
import 'package:photo_manager/photo_manager.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_image_compress/flutter_image_compress.dart';

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
      if (path.isAll) {
         final assets = await path.getAssetListRange(start: 0, end: 1000);
         allAssets.addAll(assets);
         break;
      }
    }
    
    return allAssets;
  }

  Future<File?> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = p.basename(file.path);
    final targetPath = p.join(tempDir.path, "compressed_${DateTime.now().millisecondsSinceEpoch}_$fileName");

    final XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80,
      minWidth: 1920,
      minHeight: 1080,
    );

    return result != null ? File(result.path) : null;
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

    List<File> tempFiles = [];
    try {
      for (var file in files) {
        File fileToAdd = file;
        final ext = p.extension(file.path).toLowerCase();
        if (['.jpg', '.jpeg', '.png'].contains(ext)) {
          final compressed = await _compressImage(file);
          if (compressed != null) {
            fileToAdd = compressed;
            tempFiles.add(compressed);
          }
        }
        encoder.addFile(fileToAdd);
      }
    } finally {
      encoder.close();
      // Cleanup temp files
      for (var f in tempFiles) {
        if (await f.exists()) await f.delete();
      }
    }

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

  Future<File> generatePdf(List<File> images, String pdfName) async {
    final pdf = pw.Document();
    List<File> tempFiles = [];

    try {
      for (var imageFile in images) {
        File fileToUse = imageFile;
        final ext = p.extension(imageFile.path).toLowerCase();
        if (['.jpg', '.jpeg', '.png'].contains(ext)) {
          final compressed = await _compressImage(imageFile);
          if (compressed != null) {
            fileToUse = compressed;
            tempFiles.add(compressed);
          }
        }

        final image = pw.MemoryImage(fileToUse.readAsBytesSync());
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$pdfName.pdf');
      await file.writeAsBytes(await pdf.save());
      return file;
    } finally {
      // Cleanup temp files
      for (var f in tempFiles) {
        if (await f.exists()) await f.delete();
      }
    }
  }
}
