import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:openapi_spec/openapi_spec.dart';

class YamlProcessor {
  void processFiles(List<File> yamlFiles, Directory outputDir) {
    print('🚀 Processing ${yamlFiles.length} YAML files:');
    
    for (final file in yamlFiles) {
      try {
        final content = file.readAsStringSync();
        _validateOpenAPI(content, file.path);
        final json = _convertToJson(content);
        _saveJsonFile(file, json, outputDir);
      } catch (e) {
        print('⚠️ Error processing ${path.basename(file.path)}: $e');
      }
    }
  }

  String _convertToJson(String yamlContent) {
    final yaml = loadYaml(yamlContent);
    return JsonEncoder.withIndent('  ').convert(yaml);
  }

  void _validateOpenAPI(String content, String filePath) {
    try {
      final format = filePath.endsWith('.json') 
          ? OpenApiFormat.json 
          : OpenApiFormat.yaml;
      
      OpenApi.fromString(
        source: content,
        format: format,
      );
    } catch (e) {
      throw FormatException('Invalid OpenAPI specification: ${e.toString()}');
    }
  }

  void _saveJsonFile(File originalFile, String jsonContent, Directory outputDir) {
    final fileName = '${path.basenameWithoutExtension(originalFile.path)}.json';
    File(path.join(outputDir.path, fileName))
      ..writeAsStringSync(jsonContent);
    print('✓ ${path.basename(originalFile.path)} → $fileName');
  }
}