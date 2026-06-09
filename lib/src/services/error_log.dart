part of '../../main.dart';

class AppErrorLog {
  AppErrorLog._();

  static final AppErrorLog instance = AppErrorLog._();
  static const _maxBytes = 15 * 1024 * 1024;
  static const _maxFilesPerVersion = 2;

  Directory? _directory;
  String _version = 'unknown';
  File? _activeFile;
  bool _ready = false;

  String get version => _version;

  Future<void> load() async {
    try {
      _version = await _resolveVersion();
      final baseDir = await _appDirectory();
      _directory = Directory('${baseDir.path}/NoNetCom/error-logs');
      if (!_directory!.existsSync()) {
        _directory!.createSync(recursive: true);
      }
      await _deleteLogsFromOtherVersions();
      _activeFile = await _selectActiveFile();
      _ready = true;
      await logInfo('Logger błędów uruchomiony dla wersji $_version');
    } on Object {
      _ready = false;
    }
  }

  Future<void> logFlutter(FlutterErrorDetails details) {
    return logError(
      details.exception,
      details.stack,
      source: 'flutter',
      context: details.context?.toStringDeep(),
      library: details.library,
    );
  }

  Future<void> logError(
    Object error,
    StackTrace? stack, {
    required String source,
    String? context,
    String? library,
  }) {
    return _append(
      [
        'level=error',
        'source=$source',
        if (library != null) 'library=$library',
        if (context != null) 'context=${_oneLine(context)}',
        'error=${_oneLine(error)}',
        if (stack != null) 'stack=$stack',
      ].join('\n'),
    );
  }

  Future<void> logInfo(String message) {
    return _append('level=info\nmessage=${_oneLine(message)}');
  }

  Future<String> readAll() async {
    if (!_ready) await load();
    final files = await _versionFiles();
    final buffer = StringBuffer();
    for (final file in files) {
      if (!file.existsSync()) continue;
      buffer
        ..writeln('===== ${file.uri.pathSegments.last} =====')
        ..writeln(await file.readAsString())
        ..writeln();
    }
    return buffer.toString().trimRight();
  }

  Future<List<File>> filesForCurrentVersion() async {
    if (!_ready) await load();
    return _versionFiles();
  }

  Future<int> totalBytes() async {
    final files = await filesForCurrentVersion();
    var total = 0;
    for (final file in files) {
      if (file.existsSync()) {
        total += await file.length();
      }
    }
    return total;
  }

  Future<File> exportCombinedFile({String? appendix}) async {
    if (!_ready) await load();
    final directory = _directory ?? await _appDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File('${directory.path}/nonetcom-error-log-export-$stamp.log');
    final content = StringBuffer(await readAll());
    if (appendix != null && appendix.trim().isNotEmpty) {
      if (content.isNotEmpty) {
        content.writeln();
        content.writeln();
      }
      content
        ..writeln('===== diagnostic-metadata.json =====')
        ..write(appendix);
    }
    await file.writeAsString(content.toString());
    return file;
  }

  Future<void> clearCurrentVersion() async {
    if (!_ready) await load();
    for (final file in await _versionFiles()) {
      if (file.existsSync()) {
        await file.delete();
      }
    }
    _activeFile = await _selectActiveFile();
  }

  Future<void> _append(String body) async {
    if (!_ready || _activeFile == null) return;
    final file = await _fileForWrite();
    final entry = [
      '---',
      'time=${DateTime.now().toIso8601String()}',
      'app=$_serviceName',
      'version=$_version',
      body,
      '',
    ].join('\n');
    await file.writeAsString(entry, mode: FileMode.append, flush: true);
  }

  Future<File> _fileForWrite() async {
    var file = _activeFile ?? await _selectActiveFile();
    if (file.existsSync() && await file.length() >= _maxBytes) {
      file = await _rotateFile(file);
      _activeFile = file;
    }
    return file;
  }

  Future<File> _rotateFile(File current) async {
    final files = await _versionFiles();
    if (files.length >= _maxFilesPerVersion) {
      files.sort(
        (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
      );
      final oldest = files.first;
      if (oldest.path != current.path && oldest.existsSync()) {
        await oldest.delete();
      }
    }
    final usedIndexes = (await _versionFiles())
        .map((file) => _indexFromFile(file))
        .whereType<int>()
        .toSet();
    for (var index = 0; index < _maxFilesPerVersion; index += 1) {
      if (!usedIndexes.contains(index)) {
        return File('${_directory!.path}/${_fileName(index)}');
      }
    }
    return File('${_directory!.path}/${_fileName(0)}');
  }

  Future<File> _selectActiveFile() async {
    final files = await _versionFiles();
    if (files.isEmpty) {
      return File('${_directory!.path}/${_fileName(0)}');
    }
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final newest = files.first;
    if (await newest.length() < _maxBytes) {
      return newest;
    }
    return _rotateFile(newest);
  }

  Future<List<File>> _versionFiles() async {
    final directory = _directory;
    if (directory == null || !directory.existsSync()) return [];
    final prefix = 'nonetcom-errors-${_safeVersion()}-';
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.uri.pathSegments.last.startsWith(prefix))
        .where((file) => file.uri.pathSegments.last.endsWith('.log'))
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<void> _deleteLogsFromOtherVersions() async {
    final directory = _directory;
    if (directory == null || !directory.existsSync()) return;
    final currentPrefix = 'nonetcom-errors-${_safeVersion()}-';
    for (final file in directory.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      final oldVersionLog =
          name.startsWith('nonetcom-errors-') &&
          !name.startsWith(currentPrefix);
      if (oldVersionLog || name.startsWith('nonetcom-error-log-export-')) {
        await file.delete();
      }
    }
  }

  int? _indexFromFile(File file) {
    final name = file.uri.pathSegments.last;
    final match = RegExp(r'-(\d+)\.log$').firstMatch(name);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String _fileName(int index) => 'nonetcom-errors-${_safeVersion()}-$index.log';

  String _safeVersion() =>
      _version.replaceAll(RegExp(r'[^A-Za-z0-9._+-]'), '_');

  String _oneLine(Object value) =>
      value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<String> _resolveVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } on Object {
      return 'test';
    }
  }

  Future<Directory> _appDirectory() async {
    try {
      return getApplicationDocumentsDirectory();
    } on MissingPluginException {
      return Directory.systemTemp.createTempSync('nonetcom-error-log-');
    }
  }
}
