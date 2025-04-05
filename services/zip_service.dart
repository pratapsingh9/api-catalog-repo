import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

class ZipService {
  void createZip(Directory sourceDir, String releasesDir) {
    final archive = Archive();
    final files = sourceDir.listSync(recursive: true).whereType<File>();

    for (final file in files) {
      final relativePath = path.relative(file.path, from: sourceDir.path);
      archive.addFile(ArchiveFile(
        relativePath,
        file.lengthSync(),
        file.readAsBytesSync(),
      ));
    }

    final zipFile = File(path.join(releasesDir, 'final.zip'));
    zipFile
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(ZipEncoder().encode(archive)!);
    
    print('\n📦 Created ZIP archive at: ${zipFile.path}');
    print('  Contains ${files.length} files');
  }

  void createEmptyZip(String releasesDir) {
    final zipFile = File(path.join(releasesDir, 'final.zip'));
    final archive = Archive();
    
    zipFile
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(ZipEncoder().encode(archive)!);
    
    print('ℹ️ Created empty final.zip');
  }
}