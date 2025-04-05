import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';
import 'package:yaml/yaml.dart';
import 'package:openapi_spec/openapi_spec.dart';

void main() {
  try {
    // 1. Setup directories
    final sourcesDir = Directory('sources');
    final generatedDir = Directory('generated');
    final releasesDir = Directory('releases');

    // 2. Find YAML files
    final yamlFiles = sourcesDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.yaml') || f.path.endsWith('.yml'))
        .toList();

    if (yamlFiles.isEmpty) {
      print('❌ No OpenAPI YAML files found in sources/');
      exit(1);
    }

    // 3. Process files
    generatedDir.createSync(recursive: true);
    final List<File> validFiles = [];

    for (final file in yamlFiles) {
      try {
        // Validate OpenAPI
        final content = file.readAsStringSync();
        OpenApi.fromString(source: content, format: OpenApiFormat.yaml);

        // Convert to JSON
        final relativePath = path.relative(file.path, from: sourcesDir.path);
        final jsonPath = path.join(generatedDir.path, 
            path.setExtension(relativePath, '.json'));
        
        Directory(path.dirname(jsonPath)).createSync(recursive: true);
        File(jsonPath).writeAsStringSync(
          JsonEncoder.withIndent('  ').convert(loadYaml(content))
        );
        
        validFiles.add(file);
        print('✓ Valid OpenAPI: ${file.path}');
      } catch (e) {
        print('⚠️ Invalid OpenAPI (skipped): ${file.path} - ${e.toString().split('\n').first}');
      }
    }

    if (validFiles.isEmpty) {
      print('❌ No valid OpenAPI files found');
      exit(1);
    }

    // 4. Create ZIP
    final archive = Archive();
    generatedDir.listSync(recursive: true).whereType<File>().forEach((file) {
      archive.addFile(ArchiveFile(
        path.relative(file.path, from: generatedDir.path),
        file.lengthSync(),
        file.readAsBytesSync()
      ));
    });

    releasesDir.createSync(recursive: true);
    File(path.join(releasesDir.path, 'final.zip'))
      ..writeAsBytesSync(ZipEncoder().encode(archive)!);
    
    print('\n✅ Created ZIP with ${validFiles.length} OpenAPI specs');
  } catch (e) {
    print('\n❌ Fatal error: ${e.toString()}');
    exit(1);
  }
}