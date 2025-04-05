import 'dart:io';
import 'services/file_service.dart';
import 'services/yaml_processor.dart';
import 'services/zip_service.dart';

void main() {
  try {
    final processor = OpenAPIProcessor(
      fileService: FileService(),
      yamlProcessor: YamlProcessor(),
      zipService: ZipService(),
    );
    processor.process();
  } catch (e) {
    print('\n❌ Fatal error: $e');
    exit(1);
  }
}

class OpenAPIProcessor {
  final FileService fileService;
  final YamlProcessor yamlProcessor;
  final ZipService zipService;

  OpenAPIProcessor({
    required this.fileService,
    required this.yamlProcessor,
    required this.zipService,
  });

  void process() {
    // Initialize directory structure
    final directories = fileService.initializeDirectories();
    
    // Process YAML files
    final yamlFiles = fileService.findYamlFiles(directories.sourcesDir);
    
    if (yamlFiles.isEmpty) {
      print('ℹ️ No YAML files found in sources directory');
      zipService.createEmptyZip(directories.releasesDir);
      exit(0);
    }

    // Convert and package files
    final tempDir = fileService.createTempDir();
    yamlProcessor.processFiles(yamlFiles, tempDir, directories.sourcesDir);
    zipService.createZip(tempDir, directories.releasesDir);
    
    // Cleanup
    fileService.cleanup(tempDir);
    print('\n✅ Success! Created final.zip in releases directory');
  }
}