import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';

void main() {
  try {
    // Get environment variables
    final runId = Platform.environment['GITHUB_RUN_ID'] ?? 'local';
    
    // Set directory paths
    final projectRoot = path.normalize(path.join(path.dirname(Platform.script.toFilePath()), '..'));
    final sourcesDir = path.join(projectRoot, 'sources');
    final outputDir = path.join(projectRoot, 'generated');
    final releasesDir = path.join(projectRoot, 'releases');

    // Create directories if they don't exist
    Directory(releasesDir).createSync(recursive: true);
    Directory(outputDir).createSync(recursive: true);

    // Process YAML files into a single JSON
    print('📦 Processing YAML files into single final.json...');
    final combinedJson = processAllYamlFiles(sourcesDir);

    // Write the combined JSON to final.json
    final outputFile = File(path.join(outputDir, 'final.json'));
    outputFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(combinedJson));
    print('✓ Created final.json');

    // Create ZIP archive
    final zipName = 'generated-json-$runId.zip';
    final zipPath = path.join(releasesDir, zipName);
    ZipCreator.createFromDirectory(outputDir, zipPath);
    
    // Clean up old releases (keep last 5)
    _cleanOldReleases(releasesDir);
    
    print('\n✅ Successfully created $zipPath');
  } catch (e) {
    print('\n❌ Error: $e');
    exit(1);
  }
}

Map<String, dynamic> processAllYamlFiles(String sourcesDir) {
  final combined = <String, dynamic>{};
  final files = Directory(sourcesDir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.yaml') || f.path.endsWith('.yml'))
      .toList();

  if (files.isEmpty) throw Exception('No YAML files found in $sourcesDir');
  
  print('Found ${files.length} YAML file(s):');
  
  for (final file in files) {
    try {
      final content = file.readAsStringSync();
      final json = jsonDecode(jsonEncode(loadYaml(content)));
      final fileName = path.basenameWithoutExtension(file.path);
      
      combined[fileName] = json;
      print('  ✓ Added ${path.basename(file.path)} to final.json');
    } catch (e) {
      throw Exception('Failed to process ${file.path}: $e');
    }
  }
  
  return combined;
}

class ZipCreator {
  static void createFromDirectory(String sourceDir, String zipPath) {
    try {
      print('\n🗜 Creating ZIP archive...');
      final archive = Archive();
      final files = Directory(sourceDir).listSync(recursive: true).whereType<File>();
      
      if (files.isEmpty) throw Exception('No files found in $sourceDir');
      
      files.forEach((file) {
        final relativePath = path.relative(file.path, from: sourceDir);
        archive.addFile(ArchiveFile(
          relativePath,
          file.lengthSync(),
          file.readAsBytesSync()
        ));
        print('  + $relativePath');
      });

      File(zipPath)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(ZipEncoder().encode(archive)!);
      
      print('✓ Created ${path.basename(zipPath)} (${_formatSize(File(zipPath).lengthSync())})');
    } catch (e) {
      throw Exception('ZIP creation failed: $e');
    }
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}

void _cleanOldReleases(String releasesDir) {
  try {
    final releaseFiles = Directory(releasesDir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip'))
        .toList();

    if (releaseFiles.length > 5) {
      print('\n🧹 Cleaning up old releases (keeping latest 5)...');
      // Sort by modified time (newest first)
      releaseFiles.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      
      // Delete all but the newest 5
      for (var i = 5; i < releaseFiles.length; i++) {
        final file = releaseFiles[i];
        print('  - Deleting ${path.basename(file.path)}');
        file.deleteSync();
      }
    }
  } catch (e) {
    print('⚠️ Could not clean old releases: $e');
  }
}