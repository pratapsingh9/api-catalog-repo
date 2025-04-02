import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';

void main() {
  // Get paths relative to the script location
  final scriptDir = path.dirname(Platform.script.toFilePath());
  final projectRoot = path.normalize(path.join(scriptDir, '..'));
  
  // Set default directories
  final sourcesDir = path.join(projectRoot, 'sources');
  final outputDir = path.join(projectRoot, 'generated');
  final releasesDir = path.join(projectRoot, 'releases');

  // Convert specs to JSON
  print('Processing OpenAPI specs from: $sourcesDir');
  final processor = ApiProcessor(sourcesDir, outputDir);
  processor.convertSpecs();

  // Create ZIP archive
  final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
  final zipName = 'openapi-specs-$timestamp.zip';
  final zipPath = path.join(releasesDir, zipName);
  
  print('Creating ZIP archive at: $zipPath');
  ZipCreator.create(releasesDir, zipPath, sourceDir: outputDir);
  
  print('✅ Processing completed successfully');
}

class ApiProcessor {
  final String sourcesDir;
  final String outputDir;

  ApiProcessor(this.sourcesDir, this.outputDir);

  void convertSpecs() {
    final files = _findSpecFiles();
    if (files.isEmpty) {
      print('⚠️ No YAML files found in $sourcesDir');
      return;
    }
    
    print('Found ${files.length} YAML file(s) to process');
    files.forEach(_processFile);
  }

  List<File> _findSpecFiles() {
    return Directory(sourcesDir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => _isYaml(f.path))
        .toList();
  }

  void _processFile(File file) {
    try {
      final content = file.readAsStringSync();
      final json = _convertToJson(content, file.path);
      
      final outputPath = _getOutputPath(file);
      File(outputPath)
        ..createSync(recursive: true)
        ..writeAsStringSync(JsonEncoder.withIndent('  ').convert(json));
      
      print('  Converted: ${path.basename(file.path)} → ${path.relative(outputPath, from: outputDir)}');
    } catch (e) {
      print('❌ Error processing ${file.path}: $e');
      exit(1);
    }
  }

  String _getOutputPath(File source) {
    final relative = path.relative(source.path, from: sourcesDir);
    return path.join(outputDir, relative.replaceAll(RegExp(r'\.ya?ml$'), '.json'));
  }

  bool _isYaml(String path) => path.endsWith('.yaml') || path.endsWith('.yml');

  Map<String, dynamic> _convertToJson(String content, String path) {
    if (_isYaml(path)) {
      return jsonDecode(jsonEncode(loadYaml(content)));
    }
    return jsonDecode(content);
  }
}

class ZipCreator {
  static void create(String releasesDir, String zipPath, {required String sourceDir}) {
    try {
      Directory(releasesDir).createSync(recursive: true);
      final archive = Archive();
      final files = Directory(sourceDir)
        .listSync(recursive: true)
        .whereType<File>()
        .toList();
      
      if (files.isEmpty) {
        print('⚠️ No files found to include in ZIP at $sourceDir');
        return;
      }
      
      print('Adding ${files.length} file(s) to ZIP');
      for (final file in files) {
        final relativePath = path.relative(file.path, from: sourceDir);
        archive.addFile(ArchiveFile(
          relativePath,
          file.lengthSync(),
          file.readAsBytesSync()
        ));
        print('  + $relativePath');
      }

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) throw Exception('Failed to create ZIP');
      
      File(zipPath).writeAsBytesSync(zipBytes);
      print('ZIP created (${(zipBytes.length / 1024).toStringAsFixed(2)} KB)');
    } catch (e) {
      print('❌ Error creating ZIP: $e');
      exit(1);
    }
  }
}