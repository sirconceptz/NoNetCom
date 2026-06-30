// ignore_for_file: invalid_use_of_protected_member

part of '../../../main.dart';

extension _VoiceController on _ChatShellState {
  Future<void> _toggleVoiceRecording() async {
    if (_recordingVoice) {
      await _stopAndSendVoiceRecording();
      return;
    }
    final contact = _selectedContact;
    if (contact == null || _selectedGroup != null) return;
    if (contact.publicKey == null) {
      setState(() => _status = 'Czekam na bezpieczne połączenie z kontaktem');
      _showFeedback('Głos będzie dostępny po połączeniu z tą osobą.');
      await _sendHello(contact.id);
      return;
    }
    try {
      await _voice.start();
      _voiceTimer?.cancel();
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_recordingVoice) return;
        final next = _voiceElapsed + const Duration(seconds: 1);
        setState(() => _voiceElapsed = next);
        if (next >= _maxVoiceMessageDuration) {
          unawaited(_stopAndSendVoiceRecording());
        }
      });
      await _recordDiagnostic(
        'voice_recording_started',
        'Rozpoczęto nagrywanie wiadomości głosowej',
      );
      setState(() {
        _recordingVoice = true;
        _voiceTargetContactId = contact.id;
        _voiceElapsed = Duration.zero;
        _status = 'Nagrywanie wiadomości głosowej';
      });
      _showFeedback('Nagrywam. Stuknij stop, aby wysłać wiadomość głosową.');
    } on VoiceMessageException catch (error) {
      await _recordDiagnostic(
        'voice_recording_permission_denied',
        error.message,
        level: DiagnosticLevel.warning,
      );
      setState(() => _status = error.message);
      _showFeedback(
        'Brak dostępu do mikrofonu. Przyznaj zgodę w ustawieniach.',
      );
    } on Object catch (error, stack) {
      await AppErrorLog.instance.logError(
        error,
        stack,
        source: 'voice_recording_start',
      );
      setState(() => _status = 'Nie udało się uruchomić mikrofonu');
      _showFeedback('Nie udało się uruchomić mikrofonu. Spróbuj ponownie.');
    }
  }

  Future<void> _stopAndSendVoiceRecording() async {
    if (!_recordingVoice) return;
    _voiceTimer?.cancel();
    _voiceTimer = null;
    final targetContact = _voiceTargetContactId == null
        ? null
        : _store.contact(_voiceTargetContactId!);
    _voiceTargetContactId = null;
    setState(() => _recordingVoice = false);
    try {
      final recording = await _voice.stop();
      if (recording == null ||
          recording.duration < const Duration(seconds: 1)) {
        setState(() {
          _voiceElapsed = Duration.zero;
          _status = 'Nagranie było zbyt krótkie';
        });
        _showFeedback('Nagranie było zbyt krótkie, nie wysłałem go.');
        return;
      }
      if (recording.size > _maxVoiceMessageBytes) {
        final file = File(recording.path);
        if (file.existsSync()) await file.delete();
        setState(() {
          _voiceElapsed = Duration.zero;
          _status = 'Wiadomość głosowa przekroczyła limit 5 MB';
        });
        _showFeedback('Nagranie jest za duże. Nagraj krótszą wiadomość.');
        return;
      }
      if (targetContact == null) {
        final file = File(recording.path);
        if (file.existsSync()) await file.delete();
        setState(() {
          _voiceElapsed = Duration.zero;
          _status = 'Kontakt dla nagrania jest już niedostępny';
        });
        _showFeedback(
          'Kontakt jest poza zasięgiem. Nagraj ponownie, gdy połączenie wróci.',
        );
        return;
      }
      await _sendLocalAttachment(
        path: recording.path,
        name: recording.name,
        size: recording.size,
        attachmentType: MessageAttachmentType.voice,
        voiceDurationMs: recording.duration.inMilliseconds,
        targetContact: targetContact,
      );
      await _recordDiagnostic(
        'voice_message_queued',
        'Wiadomość głosowa dodana do kolejki',
      );
      setState(() => _voiceElapsed = Duration.zero);
      _showFeedback('Wiadomość głosowa dodana do wysłania.');
    } on Object catch (error, stack) {
      await AppErrorLog.instance.logError(
        error,
        stack,
        source: 'voice_recording_stop',
      );
      setState(() {
        _voiceElapsed = Duration.zero;
        _status = 'Nie udało się zapisać wiadomości głosowej';
      });
      _showFeedback('Nie udało się zapisać nagrania. Spróbuj ponownie.');
    }
  }

  Future<void> _cancelVoiceRecording() async {
    if (!_recordingVoice) return;
    _voiceTimer?.cancel();
    _voiceTimer = null;
    _voiceTargetContactId = null;
    await _voice.cancel();
    await _recordDiagnostic(
      'voice_recording_cancelled',
      'Anulowano wiadomość głosową',
    );
    setState(() {
      _recordingVoice = false;
      _voiceElapsed = Duration.zero;
      _status = 'Nagranie anulowane';
    });
    _showFeedback('Nagranie anulowane.');
  }

  Future<void> _playVoiceMessage(ChatMessage message) async {
    final path = message.filePath;
    if (path == null || !File(path).existsSync()) {
      setState(() => _status = 'Plik wiadomości głosowej jest niedostępny');
      return;
    }
    try {
      await _voice.play(path);
      setState(() => _status = 'Odtwarzam wiadomość głosową');
    } on Object catch (error, stack) {
      await AppErrorLog.instance.logError(
        error,
        stack,
        source: 'voice_playback',
      );
      setState(() => _status = 'Nie udało się odtworzyć nagrania');
    }
  }
}
