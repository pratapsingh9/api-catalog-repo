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
    final inputDir = path.join(projectRoot, 'generated');
    final releasesDir = path.join(projectRoot, 'releases');

    // Create directories if they don't exist
    Directory(releasesDir).createSync(recursive: true);

    // Process all JSON files in the generated directory
    final jsonFiles = Directory(inputDir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    if (jsonFiles.isEmpty) {
      throw Exception('No JSON files found in $inputDir');
    }

    print('Found ${jsonFiles.length} JSON file(s) to process:');
    
    // Process each JSON file to YAML and create individual zip files
    for (final jsonFile in jsonFiles) {
      try {
        final fileName = path.basenameWithoutExtension(jsonFile.path);
        final yamlContent = _convertJsonToYaml(jsonFile);
        
        // Create a temporary directory for the YAML file
        final tempDir = Directory(path.join(Directory.systemTemp.path, 'yaml_temp_$fileName'));
        tempDir.createSync(recursive: true);
        
        // Write the YAML file
        final yamlFile = File(path.join(tempDir.path, '$fileName.yaml'));
        yamlFile.writeAsStringSync(yamlContent);
        
        // Create zip file
        final zipName = '$fileName-$runId.zip';
        final zipPath = path.join(releasesDir, zipName);
        ZipCreator.createFromDirectory(tempDir.path, zipPath);
        
        // Clean up temporary directory
        tempDir.deleteSync(recursive: true);
        
        print('✓ Created $zipPath');
      } catch (e) {
        throw Exception('Failed to process ${jsonFile.path}: $e');
      }
    }
    
    // Clean up old releases (keep last 5)
    _cleanOldReleases(releasesDir);
    
    print('\n✅ Successfully created ${jsonFiles.length} ZIP file(s) in $releasesDir');
  } catch (e) {
    print('\n❌ Error: $e');
    exit(1);
  }
}

String _convertJsonToYaml(File jsonFile) {
  try {
    final jsonContent = jsonFile.readAsStringSync();
    final jsonData = jsonDecode(jsonContent);
    return jsonData is Map ? YamlMap.wrap(jsonData).toString() : jsonData.toString();
  } catch (e) {
    throw Exception('JSON to YAML conversion failed: $e');
  }
}

class ZipCreator {
  static void createFromDirectory(String sourceDir, String zipPath) {
    try {
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
      });

      File(zipPath)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(ZipEncoder().encode(archive)!);
    } catch (e) {
      throw Exception('ZIP creation failed: $e');
    }
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