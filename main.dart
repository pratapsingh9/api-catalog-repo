import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';
import 'package:yaml/yaml.dart';
import 'package:openapi_spec/openapi_spec.dart';

void main() {
  final sourcesDir = Directory('sources');
  final releasesDir = Directory('releases');
  releasesDir.createSync(recursive: true);
  final zipFile = File(path.join(releasesDir.path, 'final.zip'));

  final yamlFiles = sourcesDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.yaml') || f.path.endsWith('.yml'));

  if (yamlFiles.isEmpty) throw Exception('No YAML files found');

  final archive = Archive();
  for (final file in yamlFiles) {
    try {
      final content = file.readAsStringSync();
      OpenApi.fromString(source: content, format: OpenApiFormat.yaml);
      final json = JsonEncoder.withIndent('  ').convert(loadYaml(content));
      archive.addFile(ArchiveFile(
        path.relative(file.path, from: sourcesDir.path)
            .replaceAll('.yaml', '.json')
            .replaceAll('.yml', '.json'),
        json.length,
        utf8.encode(json)
      ));
    } catch (e) {
      print('⚠️ Skipped ${file.path}: ${e.toString().split('\n').first}');
    }
  }

  // 3. Save ZIP
  zipFile.writeAsBytesSync(ZipEncoder().encode(archive)!);
  print('✅ Created ${zipFile.path} (${archive.files.length} files)');
}