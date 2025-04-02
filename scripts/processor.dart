import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;

void main() {
  final sourcesDir = Platform.environment['SOURCES_DIR'] ?? './sources';
  final outputDir = Platform.environment['OUTPUT_DIR'] ?? './generated';

  Directory(outputDir).createSync(recursive: true);
  
  final processor = ApiProcessor(sourcesDir, outputDir);
  processor.run();
}

class ApiProcessor {
  final String sourcesDir;
  final String outputDir;

  ApiProcessor(this.sourcesDir, this.outputDir);

  void run() {
    final files = _findSpecFiles();
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
      
      print('Processed: ${file.path} → $outputPath');
    } catch (e) {
      print('Error processing ${file.path}: $e');
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