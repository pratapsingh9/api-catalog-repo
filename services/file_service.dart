import 'dart:io';
import 'package:path/path.dart' as path;

class DirectorySet {
  final String sourcesDir;
  final String releasesDir;

  DirectorySet(this.sourcesDir, this.releasesDir);
}

class FileService {
  DirectorySet initializeDirectories() {
    final scriptDir = path.dirname(Platform.script.toFilePath());
    final projectRoot = path.normalize(path.join(scriptDir, '..'));
    final sourcesDir = path.join(projectRoot, 'sources');
    final releasesDir = path.join(projectRoot, 'releases');

    _ensureDirectoryExists(sourcesDir);
    _ensureDirectoryExists(releasesDir);

    print('📂 Project structure:');
    print('  Sources dir: $sourcesDir');
    print('  Releases dir: $releasesDir');

    return DirectorySet(sourcesDir, releasesDir);
  }

  List<File> findYamlFiles(String sourcesDir) {
    return Directory(sourcesDir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.yaml') || f.path.endsWith('.yml'))
        .toList();
  }

  Directory createTempDir() {
    final tempDir = Directory(path.join(Directory.systemTemp.path, 'openapi_json_${DateTime.now().millisecondsSinceEpoch}'));
    tempDir.createSync(recursive: true);
    return tempDir;
  }

  void cleanup(Directory directory) {
    try {
      directory.deleteSync(recursive: true);
    } catch (e) {
      print('⚠️ Could not clean up temp directory: ${directory.path}');
    }
  }

  void _ensureDirectoryExists(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      print('ℹ️ Created directory: $path');
    }
  }
}