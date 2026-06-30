// ignore_for_file: invalid_use_of_protected_member

part of '../../../main.dart';

extension _TransportController on _ChatShellState {
  Future<void> _handleBleEvent(BleEvent event) async {
    if (event.kind == BleEventKind.peer) {
      final previous = _store.contact(event.peerId);
      final reconnected = previous != null && !previous.connected;
      final keyChanged =
          previous?.trustState == TrustState.verified &&
          event.publicKey != null &&
          previous?.publicKey != null &&
          previous!.publicKey != event.publicKey;
      final contact = Contact(
        id: event.peerId,
        name: event.name?.trim().isNotEmpty == true ? event.name! : 'Kontakt',
        remoteName: event.name?.trim().isNotEmpty == true
            ? event.name!
            : 'Kontakt',
        publicKey: event.publicKey,
        lastSeen: DateTime.now(),
        connected: true,
      );
      await _store.upsertContact(contact);
      await _recordDiagnostic('peer_seen', 'Wykryto kontakt ${contact.id}');
      _selectedThreadId ??= contact.threadId;
      setState(
        () => _status = reconnected
            ? 'Połączenie z ${contact.name} wróciło'
            : 'Znaleziono: ${contact.name}',
      );
      if (keyChanged) {
        _showFeedback(
          'Klucz kontaktu się zmienił. Zweryfikuj osobę przed rozmową.',
        );
      } else if (reconnected) {
        _showFeedback('Połączenie wróciło. Wysyłam zaległe wiadomości.');
      } else {
        _showFeedback('Znaleziono ${contact.name}. Możecie zacząć rozmowę.');
      }
      await _sendHello(contact.id);
      await _flushQueuedMessages(contact.id);
      return;
    }

    if (event.kind == BleEventKind.disconnected) {
      await _store.setContactConnected(event.peerId, false);
      await _recordDiagnostic(
        'peer_disconnected',
        'Rozłączono kontakt ${event.peerId}',
        level: DiagnosticLevel.warning,
      );
      setState(() => _status = 'Kontakt czeka na zasięg');
      _showFeedback(
        'Kontakt jest poza zasięgiem. Wiadomości poczekają i wyślą się później.',
      );
      if (_liveVoiceSession?.peerId == event.peerId) {
        await _closeLiveVoiceSession(
          status: 'Rozmowa zakończona: utracono połączenie',
        );
      }
      return;
    }

    if (event.kind == BleEventKind.status && event.payload != null) {
      await _recordDiagnostic('ble_transport', event.payload!);
      return;
    }

    if (event.kind == BleEventKind.payload && event.payload != null) {
      await _handlePayload(event.peerId, event.payload!);
    }
  }

  Future<void> _handlePayload(String peerId, String payload) async {
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(payload) as Map<String, dynamic>;
    } on FormatException catch (error) {
      await _recordDiagnostic(
        'payload_parse_error',
        error.message,
        level: DiagnosticLevel.warning,
      );
      return;
    }
    if (map['type'] == 'frameAck') {
      _transport.markFrameAcked(peerId, map['frameId'] as String);
      return;
    }

    if (map['type'] == 'deliveryAck') {
      final packetId = map['packetId'] as String? ?? map['messageId'] as String;
      final delivered = _transport.markDelivered(packetId);
      if (_handleLiveVoiceDelivery(packetId)) {
        return;
      } else if (_handleConnectionCheckDelivery(packetId)) {
        return;
      } else if (delivered?.transferId != null) {
        await _markFileChunkDelivered(delivered!.transferId!, packetId);
      } else if (_groupDeliveries.containsKey(packetId)) {
        await _markGroupPacketDelivered(packetId);
      } else {
        await _store.updateMessageStatus(packetId, MessageStatus.delivered);
        await _recordDiagnostic('delivery_ack', 'Dostarczono pakiet $packetId');
        setState(() => _status = 'Wiadomość dostarczona');
      }
      return;
    }

    if (map['type'] == 'frame') {
      await _ble.send(
        peerId,
        jsonEncode({'type': 'frameAck', 'frameId': map['frameId']}),
        priority: BlePriority.control,
      );
      final completed = _transport.acceptFrame(map);
      if (completed != null) {
        await _handlePayload(peerId, completed);
      }
      return;
    }

    if (map['type'] == 'hello') {
      final previous = _store.contact(peerId);
      final reconnected = previous != null && !previous.connected;
      final incomingPublicKey = map['publicKey'] as String?;
      final keyChanged =
          previous?.trustState == TrustState.verified &&
          incomingPublicKey != null &&
          previous?.publicKey != null &&
          previous!.publicKey != incomingPublicKey;
      final contact = Contact(
        id: peerId,
        name: (map['name'] as String?)?.trim().isNotEmpty == true
            ? map['name'] as String
            : 'Kontakt',
        remoteName: (map['name'] as String?)?.trim().isNotEmpty == true
            ? map['name'] as String
            : 'Kontakt',
        publicKey: incomingPublicKey,
        lastSeen: DateTime.now(),
        connected: true,
      );
      await _store.upsertContact(contact);
      await _recordDiagnostic('hello_received', 'Odebrano hello od $peerId');
      _selectedThreadId ??= contact.threadId;
      setState(
        () => _status = reconnected
            ? 'Połączenie z ${contact.name} wróciło'
            : 'Połączono z ${contact.name}',
      );
      if (keyChanged) {
        _showFeedback(
          'Klucz kontaktu się zmienił. Zweryfikuj osobę przed rozmową.',
        );
      } else if (reconnected) {
        _showFeedback('Połączenie wróciło. Wysyłam zaległe wiadomości.');
      }
      await _flushQueuedMessages(peerId);
      return;
    }

    if (map['type'] != 'secure') {
      return;
    }
    final contact = _store.contact(peerId);
    if (contact?.publicKey == null) {
      await _recordDiagnostic(
        'missing_key',
        'Brak klucza publicznego od $peerId',
        level: DiagnosticLevel.warning,
      );
      setState(
        () => _status =
            'Połączono, ale kontakt nie jest jeszcze gotowy do rozmowy',
      );
      return;
    }
    final packetId =
        map['packetId'] as String? ?? map['messageId'] as String? ?? _newId();
    final protocolVersion = map['protocolVersion'] as int?;
    final counter = map['counter'] as int?;
    if (protocolVersion == null || counter == null) {
      await _recordDiagnostic(
        'e2ee_protocol_rejected',
        'Brak wersji protokołu lub licznika',
        level: DiagnosticLevel.warning,
      );
      return;
    }
    final String clearText;
    try {
      clearText = await _crypto.decryptText(
        peerPublicKey: contact!.publicKey!,
        packetId: packetId,
        protocolVersion: protocolVersion,
        counter: counter,
        nonce: map['nonce'] as String,
        cipherText: map['cipherText'] as String,
        mac: map['mac'] as String,
      );
    } on SecretBoxAuthenticationError catch (error) {
      await _recordDiagnostic(
        'e2ee_authentication_failed',
        error.toString(),
        level: DiagnosticLevel.warning,
      );
      return;
    } on FormatException catch (error) {
      await _recordDiagnostic(
        'e2ee_protocol_rejected',
        error.message,
        level: DiagnosticLevel.warning,
      );
      return;
    }
    if (_crypto.hasSeenCounter(contact.publicKey!, counter)) {
      await _sendDeliveryAck(peerId, packetId);
      return;
    }
    await _crypto.markCounterSeen(contact.publicKey!, counter);
    await _handleSecurePayload(
      peerId,
      contact,
      packetId,
      jsonDecode(clearText) as Map<String, dynamic>,
    );
  }

  Future<void> _sendHello(String peerId) {
    return _ble.send(
      peerId,
      jsonEncode({
        'type': 'hello',
        'name': _store.profileName,
        'publicKey': base64Encode(_crypto.cachedPublicKey),
        'protocolVersion': ChatCrypto.protocolVersion,
        'capabilities': const [
          'transport-v2',
          'e2ee-v2',
          'file-transfer',
          'live-voice',
        ],
      }),
      priority: BlePriority.control,
    );
  }

  Future<OutboundEnvelope> _queueSecurePacket({
    required Contact contact,
    required String packetId,
    required Map<String, dynamic> clearPayload,
    String? transferId,
  }) async {
    final encrypted = await _crypto.encryptText(
      peerPublicKey: contact.publicKey!,
      text: jsonEncode(clearPayload),
      packetId: packetId,
    );
    final payload = jsonEncode({
      'type': 'secure',
      'packetId': packetId,
      'transferId': transferId,
      'protocolVersion': encrypted.protocolVersion,
      'counter': encrypted.counter,
      'nonce': encrypted.nonce,
      'cipherText': encrypted.cipherText,
      'mac': encrypted.mac,
    });
    return _transport.enqueue(contact.id, payload);
  }

  Future<void> _flushQueuedMessages([String? peerId]) async {
    final ready = _transport.pendingFor(peerId);
    for (final envelope in ready) {
      await _sendQueuedEnvelope(envelope);
    }
  }

  Future<void> _sendQueuedEnvelope(OutboundEnvelope envelope) async {
    final contact = _store.contact(envelope.peerId);
    if (contact == null || !contact.connected) {
      setState(() => _status = 'Czeka na zasięg');
      return;
    }
    final attemptsExceeded = _transport.registerAttempt(envelope.id);
    if (attemptsExceeded) {
      if (_handleLiveVoiceFailure(envelope.packetId)) {
        return;
      } else if (envelope.transferId != null) {
        final transfer = _outboundFiles[envelope.transferId];
        if (transfer != null) {
          await _store.updateMessageStatus(
            transfer.messageId,
            MessageStatus.failed,
          );
          _outboundFiles.remove(envelope.transferId);
          await _store.savePendingOutboundFiles(_outboundFiles);
        }
      } else {
        final groupDelivery = _groupDeliveries.remove(envelope.packetId);
        if (groupDelivery != null) {
          _groupDeliveries.removeWhere(
            (_, delivery) => delivery.messageId == groupDelivery.messageId,
          );
          await _store.savePendingGroupDeliveries(_groupDeliveries);
        }
        await _store.updateMessageStatus(
          groupDelivery?.messageId ?? envelope.packetId,
          MessageStatus.failed,
        );
      }
      setState(() => _status = 'Nie udało się dostarczyć wiadomości');
      _showFeedback(
        'Nie udało się dostarczyć wiadomości. Spróbuj ponownie, gdy kontakt będzie blisko.',
      );
      await _recordDiagnostic(
        'delivery_failed',
        'Przekroczono limit prób dla ${envelope.packetId}',
        level: DiagnosticLevel.error,
      );
      return;
    }
    if (envelope.attempts > 1) {
      setState(() => _status = 'Wysyłam ponownie');
    }
    for (final frame in envelope.frames.where((frame) => !frame.acked)) {
      await _ble.send(
        envelope.peerId,
        jsonEncode(frame.toJson()),
        priority: _priorityForEnvelope(envelope),
      );
    }
  }

  BlePriority _priorityForEnvelope(OutboundEnvelope envelope) {
    if (envelope.packetId.startsWith('live-control:') ||
        envelope.packetId.startsWith('live-end:')) {
      return BlePriority.control;
    }
    if (envelope.packetId.startsWith('live-audio:')) {
      return BlePriority.realtime;
    }
    if (envelope.transferId != null) return BlePriority.bulk;
    return BlePriority.normal;
  }

  Future<void> _sendDeliveryAck(String peerId, String packetId) {
    return _ble.send(
      peerId,
      jsonEncode({'type': 'deliveryAck', 'packetId': packetId}),
      priority: BlePriority.control,
    );
  }
}
