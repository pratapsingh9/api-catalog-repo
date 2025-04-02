import 'dart:io';
import 'package:archive/archive.dart';

void main() {
  final outputDir = Directory('./releases');
  outputDir.createSync();
  
  final archive = Archive();
  _addGeneratedFiles(archive);
  
  final zipFile = File('${outputDir.path}/latest.zip')
    ..writeAsBytesSync(ZipEncoder().encode(archive)!);
  
  print('Created: ${zipFile.path}');
}

void _addGeneratedFiles(Archive archive) {
  Directory('./generated').listSync(recursive: true).forEach((entity) {
    if (entity is File) {
      archive.addFile(ArchiveFile(
        entity.path.replaceAll('generated/', ''),
        entity.lengthSync(),
        entity.readAsBytesSync()
      ));
    }
  });
}