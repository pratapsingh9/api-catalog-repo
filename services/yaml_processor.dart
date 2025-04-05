import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:openapi_spec/openapi_spec.dart';

class YamlProcessor {
  void processFiles(List<File> yamlFiles, Directory outputDir, String sourcesDir) {
    print('🚀 Processing ${yamlFiles.length} YAML files:');
    
    int successCount = 0;
    int errorCount = 0;

    for (final file in yamlFiles) {
      try {
        final content = file.readAsStringSync();
        _validateOpenAPI(content);
        final json = _convertToJson(content);
        _saveJsonFile(file, json, outputDir, sourcesDir);
        successCount++;
      } catch (e) {
        print('⚠️ Error processing ${path.basename(file.path)}: $e');
        errorCount++;
      }
    }

    print('\n📊 Conversion results:');
    print('✅ $successCount files converted successfully');
    if (errorCount > 0) {
      print('❌ $errorCount files failed conversion');
    }
  }

  String _convertToJson(String yamlContent) {
    final yaml = loadYaml(yamlContent);
    return JsonEncoder.withIndent('  ').convert(yaml);
  }

  void _validateOpenAPI(String content) {
    try {
      OpenApi.fromString(
        source: content,
        format: OpenApiFormat.yaml,
      );
    } catch (e) {
      throw FormatException('Invalid OpenAPI specification: ${e.toString()}');
    }
  }

  void _saveJsonFile(File originalFile, String jsonContent, Directory outputDir, String sourcesDir) {
    // Get relative path from sourcesDir to the file
    final relativePath = path.relative(originalFile.path, from: sourcesDir);
    final newPath = path.join(
      outputDir.path, 
      path.dirname(relativePath), 
      '${path.basenameWithoutExtension(relativePath)}.json'
    );

    // Ensure directory exists
    Directory(path.dirname(newPath)).createSync(recursive: true);
    
    File(newPath).writeAsStringSync(jsonContent);
    print('✓ ${originalFile.path} → $newPath');
  }
}