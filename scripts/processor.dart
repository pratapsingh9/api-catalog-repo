import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';

void main() {
  try {
    final projectRoot = path.dirname(Platform.script.toFilePath());
    final sourcesDir = path.join(projectRoot, 'sources');
    final releasesDir = path.join(projectRoot, 'releases');

    // Create required directories
    Directory(releasesDir).createSync(recursive: true);
    
    // Verify sources directory exists
    if (!Directory(sourcesDir).existsSync()) {
      throw Exception('Missing "sources" directory');
    }

    // Create temporary output directory
    final tempOutput = Directory(path.join(Directory.systemTemp.path, 'json_output'));
    tempOutput.createSync(recursive: true);

    // Process YAML files
    final yamlFiles = Directory(sourcesDir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.yaml') || f.path.endsWith('.yml'))
        .toList();

    if (yamlFiles.isEmpty) {
      print('ℹ️ No YAML files found in sources directory');
      exit(0);
    }

    print('🚀 Processing ${yamlFiles.length} YAML files:');
    for (final file in yamlFiles) {
      try {
        final yamlContent = file.readAsStringSync();
        final jsonData = jsonDecode(jsonEncode(loadYaml(yamlContent)));
        final fileName = '${path.basenameWithoutExtension(file.path)}.json';
        
        File(path.join(tempOutput.path, fileName))
          ..writeAsStringSync(JsonEncoder.withIndent('  ').convert(jsonData));
        
        print('✓ ${path.basename(file.path)} → $fileName');
      } catch (e) {
        print('⚠️ Error processing ${path.basename(file.path)}: $e');
      }
    }

    // Create final.zip
    final zipFile = File(path.join(releasesDir, 'final.zip'));
    createZip(tempOutput.path, zipFile.path);
    
    // Cleanup
    tempOutput.deleteSync(recursive: true);

    print('\n✅ Success! Created final.zip');

  } catch (e) {
    print('\n❌ Fatal error: $e');
    exit(1);
  }
}

void createZip(String sourceDir, String zipPath) {
  final archive = Archive();
  final files = Directory(sourceDir).listSync(recursive: true).whereType<File>();

  for (final file in files) {
    final relativePath = path.relative(file.path, from: sourceDir);
    archive.addFile(ArchiveFile(
      relativePath,
      file.lengthSync(),
      file.readAsBytesSync()
    ));
  }

  File(zipPath)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(ZipEncoder().encode(archive)!);
}