import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileStorageService {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/downloads';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  Future<File> saveFile(String sourcePath) async {
    final path = await _localPath;
    final fileName = p.basename(sourcePath);
    final targetPath = '$path/$fileName';
    
    final sourceFile = File(sourcePath);
    return sourceFile.copy(targetPath);
  }

  Future<List<File>> getDownloadedFiles() async {
    final path = await _localPath;
    final dir = Directory(path);
    if (!await dir.exists()) return [];
    
    final List<FileSystemEntity> entities = await dir.list().toList();
    return entities.whereType<File>().toList();
  }

  Future<void> deleteFile(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
