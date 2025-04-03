import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';

void main() {
  try {
    // Get paths relative to the current working directory instead
    final projectRoot = Directory.current.path;
    
    // Set directory paths
    final sourcesDir = path.join(projectRoot, 'sources');
    final releasesDir = path.join(projectRoot, 'releases');

    // Debug: Print directory structure
    print('📂 Project structure:');
    print('  Project root: $projectRoot');
    print('  Sources dir: $sourcesDir');
    print('  Releases dir: $releasesDir');
    
    // Verify directories exist
    if (!Directory(sourcesDir).existsSync()) {
      Directory(sourcesDir).createSync(recursive: true);
      print('ℹ️ Created sources directory as it didn\'t exist');
    }

    Directory(releasesDir).createSync(recursive: true);

    // Process YAML files
    final yamlFiles = Directory(sourcesDir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.yaml') || f.path.endsWith('.yml'))
        .toList();

    if (yamlFiles.isEmpty) {
      print('ℹ️ No YAML files found in sources directory');
      // Create empty final.zip even if no files found
      _createEmptyZip(releasesDir);
      exit(0);
    }

    print('🚀 Processing ${yamlFiles.length} YAML files:');
    final tempOutput = Directory(path.join(Directory.systemTemp.path, 'json_output'));
    if (tempOutput.existsSync()) {
      tempOutput.deleteSync(recursive: true);
    }
    tempOutput.createSync(recursive: true);

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
    if (zipFile.existsSync()) {
      zipFile.deleteSync();
    }
    _createZip(tempOutput.path, zipFile.path);
    
    // Verify the zip was created
    if (zipFile.existsSync()) {
      print('\n✅ Success! Created final.zip (${zipFile.lengthSync()} bytes)');
    } else {
      print('\n❌ Failed to create final.zip');
    }
    
    // Cleanup
    tempOutput.deleteSync(recursive: true);

  } catch (e) {
    print('\n❌ Fatal error: $e');
    exit(1);
  }
}

void _createZip(String sourceDir, String zipPath) {
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

  final zipData = ZipEncoder().encode(archive);
  if (zipData == null) {
    throw Exception('Failed to encode ZIP archive');
  }

  File(zipPath)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(zipData);
}

void _createEmptyZip(String releasesDir) {
  final zipFile = File(path.join(releasesDir, 'final.zip'));
  final archive = Archive();
  
  final zipData = ZipEncoder().encode(archive);
  if (zipData == null) {
    throw Exception('Failed to encode empty ZIP archive');
  }
  
  File(zipFile.path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(zipData);
  
  print('ℹ️ Created empty final.zip (no YAML files found)');
}
