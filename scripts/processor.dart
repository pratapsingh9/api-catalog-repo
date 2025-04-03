import 'dart:io';
import 'dart:convert';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';

void main() {
  try {
    // Get the correct project root (two levels up from script location)
    final scriptDir = path.dirname(Platform.script.toFilePath());
    final projectRoot = path.normalize(path.join(scriptDir, '..'));
    
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
    _createZip(tempOutput.path, zipFile.path);
    
    // Cleanup
    tempOutput.deleteSync(recursive: true);
    print('\n✅ Success! Created final.zip');

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

  File(zipPath)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(ZipEncoder().encode(archive)!);
}

void _createEmptyZip(String releasesDir) {
  final zipFile = File(path.join(releasesDir, 'final.zip'));
  final archive = Archive();
  
  File(zipFile.path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(ZipEncoder().encode(archive)!);
  
  print('ℹ️ Created empty final.zip (no YAML files found)');
}
