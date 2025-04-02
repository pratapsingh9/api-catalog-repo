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

    // Process specs
    print('📦 Processing API specs...');
    final processor = ApiProcessor(sourcesDir, outputDir);
    processor.convertSpecs();

    // Create ZIP
    final zipName = 'api-specs-$runId.zip';
    final zipPath = path.join(releasesDir, zipName);
    ZipCreator.createFromDirectory(outputDir, zipPath);
    
    print('\n✅ Successfully created $zipPath');
  } catch (e) {
    print('\n❌ Error: $e');
    exit(1);
  }
}

class ApiProcessor {
  final String sourcesDir;
  final String outputDir;

  ApiProcessor(this.sourcesDir, this.outputDir);

  void convertSpecs() {
    final files = _findSpecFiles();
    if (files.isEmpty) throw Exception('No YAML files found in $sourcesDir');
    
    print('Found ${files.length} specification file(s):');
    files.forEach(_processFile);
  }

  List<File> _findSpecFiles() => Directory(sourcesDir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => _isYaml(f.path))
      .toList();

  void _processFile(File file) {
    try {
      final json = _convertToJson(file.readAsStringSync(), file.path);
      final outputPath = _getOutputPath(file);
      
      File(outputPath)
        ..createSync(recursive: true)
        ..writeAsStringSync(JsonEncoder.withIndent('  ').convert(json));
      
      print('  ✓ ${path.basename(file.path)} → ${path.relative(outputPath, from: outputDir)}');
    } catch (e) {
      throw Exception('Failed to process ${file.path}: $e');
    }
  }

  String _getOutputPath(File source) => path.join(
    outputDir,
    path.relative(source.path, from: sourcesDir)
      .replaceAll(RegExp(r'\.ya?ml$'), '.json')
  );

  bool _isYaml(String path) => path.endsWith('.yaml') || path.endsWith('.yml');

  Map<String, dynamic> _convertToJson(String content, String path) {
    return _isYaml(path) 
      ? jsonDecode(jsonEncode(loadYaml(content)))
      : jsonDecode(content);
  }
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