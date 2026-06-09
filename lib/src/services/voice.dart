part of '../../main.dart';

class VoiceMessagingService {
  VoiceMessagingService({AudioRecorder? recorder, AudioPlayer? player})
    : _recorder = recorder ?? AudioRecorder(),
      _player = player ?? AudioPlayer();

  final AudioRecorder _recorder;
  final AudioPlayer _player;
  String? _recordingPath;
  DateTime? _startedAt;
  Future<void> _transientPlayback = Future<void>.value();

  bool get isRecording => _recordingPath != null;

  Future<String> start({bool live = false}) async {
    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      throw const VoiceMessageException('Brak zgody na mikrofon');
    }
    final directory = await getTemporaryDirectory();
    final voiceDir = Directory('${directory.path}/NoNetComVoice');
    if (!voiceDir.existsSync()) voiceDir.createSync(recursive: true);
    final path = '${voiceDir.path}/voice-${_newId()}.m4a';
    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: live ? 16000 : 24000,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        noiseSuppress: true,
      ),
      path: path,
    );
    _recordingPath = path;
    _startedAt = DateTime.now();
    return path;
  }

  Future<VoiceRecording?> stop() async {
    final path = await _recorder.stop();
    final startedAt = _startedAt;
    _recordingPath = null;
    _startedAt = null;
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    final size = await file.length();
    if (size <= 0) return null;
    return VoiceRecording(
      path: path,
      name: path.split(Platform.pathSeparator).last,
      size: size,
      duration: startedAt == null
          ? Duration.zero
          : DateTime.now().difference(startedAt),
    );
  }

  Future<void> cancel() async {
    final path = _recordingPath;
    _recordingPath = null;
    _startedAt = null;
    await _recorder.cancel();
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  Future<void> play(String path) async {
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  Future<void> playTransient(Uint8List bytes) async {
    final playback = _transientPlayback
        .catchError((Object _) {})
        .then((_) => _playTransientNow(bytes));
    _transientPlayback = playback.catchError((Object _) {});
    return playback;
  }

  Future<void> _playTransientNow(Uint8List bytes) async {
    final directory = await getTemporaryDirectory();
    final voiceDir = Directory('${directory.path}/NoNetComVoiceLive');
    if (!voiceDir.existsSync()) voiceDir.createSync(recursive: true);
    final file = File('${voiceDir.path}/live-${_newId()}.m4a');
    await file.writeAsBytes(bytes, flush: true);
    try {
      await _player.stop();
      final completed = _player.onPlayerComplete.first;
      await _player.play(DeviceFileSource(file.path));
      await completed.timeout(const Duration(seconds: 5), onTimeout: () {});
    } finally {
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
    await _player.dispose();
  }
}

class VoiceRecording {
  const VoiceRecording({
    required this.path,
    required this.name,
    required this.size,
    required this.duration,
  });

  final String path;
  final String name;
  final int size;
  final Duration duration;
}

class VoiceMessageException implements Exception {
  const VoiceMessageException(this.message);

  final String message;

  @override
  String toString() => message;
}
