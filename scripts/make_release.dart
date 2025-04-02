import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

void main() {
  final outputDir = Directory('./releases');
  outputDir.createSync();
  
  final archive = Archive();
  _addGeneratedFiles(archive);
  
  final zipBytes = ZipEncoder().encode(archive);
  if (zipBytes == null) throw Exception('Failed to create ZIP');
  
  final zipFile = File(path.join(outputDir.path, 'latest.zip'))
    ..writeAsBytesSync(zipBytes);
  
  print('Created: ${zipFile.path} (${zipBytes.length} bytes)');
}

void _addGeneratedFiles(Archive archive) {
  Directory('./generated').listSync(recursive: true).forEach((entity) {
    if (entity is File) {
      archive.addFile(ArchiveFile(
        path.relative(entity.path, from: 'generated'),
        entity.lengthSync(),
        entity.readAsBytesSync()
      ));
    }
  });
}