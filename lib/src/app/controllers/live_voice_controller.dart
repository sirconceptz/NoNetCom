// ignore_for_file: invalid_use_of_protected_member

part of '../../../main.dart';

extension _LiveVoiceController on _ChatShellState {
  Future<void> _startLiveVoiceSession(Contact contact) async {
    if (_liveVoiceSession != null) {
      setState(() => _status = 'Inna rozmowa głosowa jest już aktywna');
      return;
    }
    if (!contact.connected) {
      setState(() => _status = 'Kontakt jest poza zasięgiem');
      return;
    }
    if (contact.publicKey == null) {
      setState(() => _status = 'Kontakt nie ma jeszcze klucza E2EE');
      await _sendHello(contact.id);
      return;
    }
    if (_recordingVoice) {
      await _cancelVoiceRecording();
    }
    final session = LiveVoiceSession(
      id: _newId(),
      peerId: contact.id,
      peerName: contact.name,
      state: LiveVoiceState.calling,
      initiatedByMe: true,
    );
    setState(() {
      _liveVoiceSession = session;
      _liveVoiceElapsed = Duration.zero;
      _liveVoiceQuality = LiveVoiceQuality.good;
      _status = 'Łączenie rozmowy głosowej z ${contact.name}';
    });
    await _sendLiveVoiceControl(contact, session, 'liveVoiceInvite');
    _scheduleLiveVoiceResponseTimeout();
    await _recordDiagnostic(
      'live_voice_invite_sent',
      'Wysłano zaproszenie do rozmowy głosowej',
    );
  }

  Future<void> _acceptLiveVoiceSession() async {
    final session = _liveVoiceSession;
    if (session == null || session.state != LiveVoiceState.incoming) return;
    final contact = _store.contact(session.peerId);
    if (contact?.publicKey == null || contact?.connected != true) {
      await _closeLiveVoiceSession(
        status: 'Nie można rozpocząć rozmowy: kontakt jest niedostępny',
      );
      return;
    }
    await _sendLiveVoiceControl(contact!, session, 'liveVoiceAccept');
    _activateLiveVoiceSession();
    await _recordDiagnostic(
      'live_voice_accepted',
      'Zaakceptowano rozmowę głosową',
    );
  }

  Future<void> _sendLiveVoiceControl(
    Contact contact,
    LiveVoiceSession session,
    String kind, {
    String? reason,
  }) async {
    final prefix = kind == 'liveVoiceEnd' ? 'live-end' : 'live-control';
    final packetId = '$prefix:${session.id}:${_newId()}';
    final queued = await _queueSecurePacket(
      contact: contact,
      packetId: packetId,
      clearPayload: {
        'kind': kind,
        'sessionId': session.id,
        'senderName': _store.profileName,
        'reason': ?reason,
      },
    );
    await _sendQueuedEnvelope(queued);
  }

  Future<void> _handleLiveVoicePayload(
    String peerId,
    Contact contact,
    Map<String, dynamic> payload,
  ) async {
    final kind = payload['kind'] as String;
    final sessionId = payload['sessionId'] as String;
    switch (kind) {
      case 'liveVoiceInvite':
        final active = _liveVoiceSession;
        if (active != null && active.id != sessionId) {
          final busySession = LiveVoiceSession(
            id: sessionId,
            peerId: peerId,
            peerName: contact.name,
            state: LiveVoiceState.incoming,
            initiatedByMe: false,
          );
          await _sendLiveVoiceControl(
            contact,
            busySession,
            'liveVoiceEnd',
            reason: 'zajęty',
          );
          return;
        }
        setState(() {
          _liveVoiceSession = LiveVoiceSession(
            id: sessionId,
            peerId: peerId,
            peerName: contact.name,
            state: LiveVoiceState.incoming,
            initiatedByMe: false,
          );
          _liveVoiceElapsed = Duration.zero;
          _liveVoiceQuality = LiveVoiceQuality.good;
          _status = 'Przychodząca rozmowa głosowa od ${contact.name}';
        });
        await _notifications.showMessage(
          title: 'Rozmowa głosowa',
          body: '${contact.name} chce rozpocząć rozmowę',
          messageId: sessionId,
          threadId: contact.threadId,
        );
        _scheduleLiveVoiceResponseTimeout();
      case 'liveVoiceAccept':
        if (_liveVoiceSession?.id == sessionId) {
          _activateLiveVoiceSession();
        }
      case 'liveVoiceEnd':
        if (_liveVoiceSession?.id == sessionId) {
          await _closeLiveVoiceSession(
            status: 'Rozmowa głosowa została zakończona',
          );
        }
      case 'liveVoiceSegment':
        final session = _liveVoiceSession;
        if (session?.id != sessionId ||
            session?.state != LiveVoiceState.connected) {
          return;
        }
        final data = payload['data'] as String?;
        if (data == null) return;
        if (mounted) {
          setState(() => _status = '${contact.name} mówi');
        }
        unawaited(
          _voice
              .playTransient(Uint8List.fromList(base64Decode(data)))
              .catchError((Object error, StackTrace stack) {
                return AppErrorLog.instance.logError(
                  error,
                  stack,
                  source: 'live_voice_playback',
                );
              }),
        );
    }
  }

  void _activateLiveVoiceSession() {
    final session = _liveVoiceSession;
    if (session == null) return;
    _liveVoiceTimer?.cancel();
    setState(() {
      _liveVoiceSession = session.copyWith(state: LiveVoiceState.connected);
      _liveVoiceElapsed = Duration.zero;
      _status = 'Rozmowa głosowa z ${session.peerName}';
    });
    _liveVoiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _liveVoiceSession == null) return;
      final elapsed = _liveVoiceElapsed + const Duration(seconds: 1);
      setState(() => _liveVoiceElapsed = elapsed);
    });
  }

  void _scheduleLiveVoiceResponseTimeout() {
    _liveVoiceTimer?.cancel();
    _liveVoiceTimer = Timer(const Duration(seconds: 30), () {
      if (_liveVoiceSession?.state == LiveVoiceState.connected) return;
      unawaited(_endLiveVoiceSession(reason: 'brak odpowiedzi'));
    });
  }

  Future<void> _toggleLiveVoiceSpeaking() async {
    final session = _liveVoiceSession;
    if (session == null || session.state != LiveVoiceState.connected) return;
    if (_liveVoiceSpeaking) {
      setState(() => _liveVoiceSpeaking = false);
      return;
    }
    if (_recordingVoice) {
      await _cancelVoiceRecording();
    }
    setState(() {
      _liveVoiceSpeaking = true;
      _status = 'Mówisz do ${session.peerName}';
    });
    unawaited(_runLiveVoiceSegmentLoop());
  }

  Future<void> _runLiveVoiceSegmentLoop() async {
    if (_liveSegmentLoopRunning) return;
    _liveSegmentLoopRunning = true;
    try {
      while (_liveVoiceSpeaking && _liveVoiceSession != null) {
        if (_liveVoicePendingPackets.length >= _maxLiveVoicePendingSegments) {
          if (mounted) {
            setState(() => _liveVoiceQuality = LiveVoiceQuality.weak);
          }
          await Future<void>.delayed(const Duration(milliseconds: 200));
          continue;
        }
        VoiceRecording? recording;
        try {
          await _voice.start(live: true);
          await Future<void>.delayed(_liveVoiceSegmentDuration);
          recording = await _voice.stop();
        } on Object catch (error, stack) {
          await AppErrorLog.instance.logError(
            error,
            stack,
            source: 'live_voice_recording',
          );
          if (_voice.isRecording) {
            await _voice.cancel();
          }
          if (mounted) {
            setState(() {
              _liveVoiceSpeaking = false;
              _status = 'Nie udało się nagrać dźwięku';
            });
          }
          break;
        }
        if (recording != null) {
          await _sendLiveVoiceSegment(recording);
        }
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    } finally {
      _liveSegmentLoopRunning = false;
      if (mounted && _liveVoiceSession != null) {
        setState(() => _status = 'Rozmowa głosowa aktywna');
      }
    }
  }

  Future<void> _sendLiveVoiceSegment(VoiceRecording recording) async {
    final session = _liveVoiceSession;
    final contact = session == null ? null : _store.contact(session.peerId);
    final file = File(recording.path);
    try {
      if (session == null ||
          session.state != LiveVoiceState.connected ||
          contact?.publicKey == null ||
          !file.existsSync()) {
        return;
      }
      final packetId = 'live-audio:${session.id}:${_newId()}';
      final queued = await _queueSecurePacket(
        contact: contact!,
        packetId: packetId,
        clearPayload: {
          'kind': 'liveVoiceSegment',
          'sessionId': session.id,
          'durationMs': recording.duration.inMilliseconds,
          'data': base64Encode(await file.readAsBytes()),
        },
      );
      _liveVoicePendingPackets[packetId] = DateTime.now();
      _refreshLiveVoiceQuality();
      await _sendQueuedEnvelope(queued);
    } finally {
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  bool _handleLiveVoiceDelivery(String packetId) {
    if (!packetId.startsWith('live-')) return false;
    final sentAt = _liveVoicePendingPackets.remove(packetId);
    if (sentAt != null && mounted) {
      final latency = DateTime.now().difference(sentAt);
      setState(() {
        _liveVoiceQuality = latency > const Duration(seconds: 2)
            ? LiveVoiceQuality.weak
            : latency > const Duration(milliseconds: 900)
            ? LiveVoiceQuality.fair
            : LiveVoiceQuality.good;
      });
    }
    return true;
  }

  bool _handleLiveVoiceFailure(String packetId) {
    if (!packetId.startsWith('live-')) return false;
    _liveVoicePendingPackets.remove(packetId);
    if (packetId.startsWith('live-audio:') && mounted) {
      setState(() {
        _liveVoiceQuality = LiveVoiceQuality.weak;
        _status = 'Słabe połączenie: fragment głosu nie został dostarczony';
      });
    }
    return true;
  }

  void _refreshLiveVoiceQuality() {
    if (!mounted) return;
    setState(() {
      _liveVoiceQuality =
          _liveVoicePendingPackets.length >= _maxLiveVoicePendingSegments
          ? LiveVoiceQuality.weak
          : _liveVoicePendingPackets.length >= 2
          ? LiveVoiceQuality.fair
          : LiveVoiceQuality.good;
    });
  }

  Future<void> _endLiveVoiceSession({required String reason}) async {
    final session = _liveVoiceSession;
    if (session == null) return;
    final contact = _store.contact(session.peerId);
    if (contact?.publicKey != null && contact?.connected == true) {
      await _sendLiveVoiceControl(
        contact!,
        session,
        'liveVoiceEnd',
        reason: reason,
      );
    }
    await _closeLiveVoiceSession(status: 'Rozmowa głosowa zakończona');
  }

  Future<void> _closeLiveVoiceSession({required String status}) async {
    final session = _liveVoiceSession;
    if (session == null) return;
    _liveVoiceTimer?.cancel();
    _liveVoiceTimer = null;
    _liveVoiceSpeaking = false;
    if (_voice.isRecording) {
      await _voice.cancel();
    }
    _transport.discardWhere(
      (envelope) =>
          envelope.packetId.startsWith('live-audio:${session.id}:') ||
          envelope.packetId.startsWith('live-control:${session.id}:'),
    );
    _liveVoicePendingPackets.removeWhere(
      (packetId, _) => packetId.contains(session.id),
    );
    await _recordDiagnostic(
      'live_voice_ended',
      'Zakończono rozmowę głosową: $status',
    );
    if (!mounted) return;
    setState(() {
      _liveVoiceSession = null;
      _liveVoiceElapsed = Duration.zero;
      _liveVoiceQuality = LiveVoiceQuality.good;
      _status = status;
    });
  }
}
