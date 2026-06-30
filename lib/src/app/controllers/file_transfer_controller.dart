// ignore_for_file: invalid_use_of_protected_member

part of '../../../main.dart';

extension _FileTransferController on _ChatShellState {
  Future<void> _sendFile() async {
    final contact = _selectedContact;
    if (contact == null) return;
    if (contact.publicKey == null) {
      setState(() => _status = 'Czekam na bezpieczne połączenie z kontaktem');
      _showFeedback(
        'Jeszcze nie można wysłać pliku. Zostaw telefony blisko siebie.',
      );
      await _sendHello(contact.id);
      return;
    }

    final file = await FileChooserBridge.pickFile();
    if (file == null) return;
    await _sendLocalAttachment(
      path: file.path,
      name: file.name,
      size: file.size,
    );
  }

  Future<void> _sendLocalAttachment({
    required String path,
    required String name,
    required int size,
    MessageAttachmentType attachmentType = MessageAttachmentType.file,
    int? voiceDurationMs,
    Contact? targetContact,
  }) async {
    final contact = targetContact ?? _selectedContact;
    if (contact == null) return;
    if (contact.publicKey == null) {
      setState(() => _status = 'Czekam na bezpieczne połączenie z kontaktem');
      _showFeedback(
        'Kontakt nie jest jeszcze gotowy. Spróbuję, gdy połączenie będzie gotowe.',
      );
      await _sendHello(contact.id);
      return;
    }
    final maxBytes = attachmentType == MessageAttachmentType.voice
        ? _maxVoiceMessageBytes
        : _maxFileBytes;
    if (size > maxBytes) {
      await _recordDiagnostic(
        'file_rejected',
        'Odrzucono załącznik większy niż limit: $size B',
        level: DiagnosticLevel.warning,
      );
      setState(
        () => _status = attachmentType == MessageAttachmentType.voice
            ? 'Wiadomość głosowa jest zbyt duża'
            : 'Plik jest większy niż 30 MB',
      );
      _showFeedback(
        attachmentType == MessageAttachmentType.voice
            ? 'Nagranie jest zbyt duże. Nagraj krótszą wiadomość.'
            : 'Ten plik jest za duży. Maksymalny rozmiar to 30 MB.',
      );
      return;
    }

    final transferId = _newId();
    final messageId = _newId();
    final totalChunks = max(1, (size / _fileChunkBytes).ceil());
    _outboundFiles[transferId] = OutboundFileTransfer(
      transferId: transferId,
      messageId: messageId,
      totalChunks: totalChunks,
    );
    await _store.savePendingOutboundFiles(_outboundFiles);
    await _recordDiagnostic(
      attachmentType == MessageAttachmentType.voice
          ? 'voice_send_start'
          : 'file_send_start',
      'Start wysyłki załącznika $name ($size B)',
    );
    await _store.addMessage(
      ChatMessage(
        id: messageId,
        contactId: contact.threadId,
        text: attachmentType == MessageAttachmentType.voice
            ? 'Wiadomość głosowa'
            : 'Plik: $name',
        mine: true,
        sentAt: DateTime.now(),
        status: MessageStatus.sending,
        fileName: name,
        fileSize: size,
        filePath: path,
        fileTransferId: transferId,
        progress: 0,
        attachmentType: attachmentType,
        voiceDurationMs: voiceDurationMs,
      ),
    );

    final offer = await _queueSecurePacket(
      contact: contact,
      packetId: '$transferId:offer',
      transferId: transferId,
      clearPayload: {
        'kind': 'fileOffer',
        'transferId': transferId,
        'messageId': messageId,
        'name': name,
        'size': size,
        'chunks': totalChunks,
        'attachmentType': attachmentType.name,
        'voiceDurationMs': voiceDurationMs,
      },
    );
    await _sendQueuedEnvelope(offer);

    final opened = File(path).openSync();
    try {
      for (var index = 0; index < totalChunks; index += 1) {
        final bytes = opened.readSync(_fileChunkBytes);
        final packetId = '$transferId:$index';
        final chunk = await _queueSecurePacket(
          contact: contact,
          packetId: packetId,
          transferId: transferId,
          clearPayload: {
            'kind': 'fileChunk',
            'transferId': transferId,
            'index': index,
            'total': totalChunks,
            'data': base64Encode(bytes),
          },
        );
        await _sendQueuedEnvelope(chunk);
      }
    } finally {
      opened.closeSync();
    }

    final complete = await _queueSecurePacket(
      contact: contact,
      packetId: '$transferId:complete',
      transferId: transferId,
      clearPayload: {
        'kind': 'fileComplete',
        'transferId': transferId,
        'messageId': messageId,
      },
    );
    await _sendQueuedEnvelope(complete);
    setState(
      () => _status = attachmentType == MessageAttachmentType.voice
          ? 'Wysyłam wiadomość głosową'
          : 'Wysyłam plik $name',
    );
    _showFeedback(
      attachmentType == MessageAttachmentType.voice
          ? 'Wiadomość głosowa czeka na wysłanie.'
          : 'Plik dodany do wysyłania. Jeśli kontakt zniknie, wznowię automatycznie.',
    );
  }

  Future<void> _acceptFileOffer(
    String peerId,
    Map<String, dynamic> payload,
  ) async {
    final transferId = payload['transferId'] as String;
    final directory = await getApplicationDocumentsDirectory();
    final inbox = Directory('${directory.path}/NoNetCom');
    if (!inbox.existsSync()) {
      inbox.createSync(recursive: true);
    }
    final fileName = _safeFileName(payload['name'] as String);
    final attachmentType = MessageAttachmentType.values.firstWhere(
      (type) => type.name == payload['attachmentType'],
      orElse: () => MessageAttachmentType.file,
    );
    final path =
        '${inbox.path}/${DateTime.now().millisecondsSinceEpoch}-$fileName';
    final transfer = InboundFileTransfer(
      transferId: transferId,
      messageId: payload['messageId'] as String,
      peerId: peerId,
      name: fileName,
      size: payload['size'] as int,
      totalChunks: payload['chunks'] as int,
      path: path,
      file: File(path).openSync(mode: FileMode.write),
      attachmentType: attachmentType,
      voiceDurationMs: payload['voiceDurationMs'] as int?,
    );
    _inboundFiles[transferId] = transfer;
    await _recordDiagnostic(
      'file_receive_start',
      'Start odbioru pliku $fileName (${transfer.size} B)',
    );
    await _store.addMessage(
      ChatMessage(
        id: transfer.messageId,
        contactId: Contact.threadIdFor(peerId),
        text: attachmentType == MessageAttachmentType.voice
            ? 'Odbieram wiadomość głosową'
            : 'Odbieram plik: $fileName',
        mine: false,
        sentAt: DateTime.now(),
        status: MessageStatus.sending,
        fileName: fileName,
        fileSize: transfer.size,
        filePath: path,
        fileTransferId: transferId,
        progress: 0,
        attachmentType: attachmentType,
        voiceDurationMs: transfer.voiceDurationMs,
      ),
    );
    setState(
      () => _status = attachmentType == MessageAttachmentType.voice
          ? 'Rozpoczęto odbiór wiadomości głosowej'
          : 'Rozpoczęto odbiór pliku $fileName',
    );
    _showFeedback(
      attachmentType == MessageAttachmentType.voice
          ? 'Odbieram wiadomość głosową.'
          : 'Odbieram plik $fileName.',
    );
  }

  Future<void> _acceptFileChunk(
    String peerId,
    Map<String, dynamic> payload,
  ) async {
    final transferId = payload['transferId'] as String;
    final transfer = _inboundFiles[transferId];
    if (transfer == null) return;
    final index = payload['index'] as int;
    if (transfer.receivedChunks.contains(index)) return;
    final bytes = base64Decode(payload['data'] as String);
    transfer.file.setPositionSync(index * _fileChunkBytes);
    transfer.file.writeFromSync(bytes);
    transfer.receivedChunks.add(index);
    await _store.updateMessageProgress(
      transfer.messageId,
      transfer.receivedChunks.length / transfer.totalChunks,
    );
    setState(
      () => _status = 'Odbieram plik ${transfer.name}: ${transfer.percent}%',
    );
    if (transfer.completeRequested && transfer.isComplete) {
      await _finishInboundTransfer(peerId, transfer);
    }
  }

  Future<void> _completeInboundFile(
    String peerId,
    Map<String, dynamic> payload,
  ) async {
    final transfer = _inboundFiles[payload['transferId'] as String];
    if (transfer == null) return;
    transfer.completeRequested = true;
    if (transfer.isComplete) {
      await _finishInboundTransfer(peerId, transfer);
    }
  }

  Future<void> _finishInboundTransfer(
    String peerId,
    InboundFileTransfer transfer,
  ) async {
    transfer.file.closeSync();
    _inboundFiles.remove(transfer.transferId);
    await _recordDiagnostic(
      'file_receive_complete',
      'Odebrano plik ${transfer.name}',
    );
    await _store.updateMessageProgress(transfer.messageId, 1);
    await _store.updateMessageStatus(
      transfer.messageId,
      MessageStatus.delivered,
    );
    if (transfer.attachmentType == MessageAttachmentType.voice) {
      final contact = _store.contact(peerId);
      await _notifyIncomingMessage(
        threadId: Contact.threadIdFor(peerId),
        title: contact?.name ?? 'NoNetCom',
        body: 'Nowa wiadomość głosowa',
        messageId: transfer.messageId,
      );
    }
    setState(
      () => _status = transfer.attachmentType == MessageAttachmentType.voice
          ? 'Odebrano wiadomość głosową'
          : 'Odebrano plik ${transfer.name}',
    );
  }

  Future<void> _markFileChunkDelivered(
    String transferId,
    String packetId,
  ) async {
    final transfer = _outboundFiles[transferId];
    if (transfer == null) return;
    if (packetId.endsWith(':offer') || packetId.endsWith(':complete')) {
      return;
    }
    transfer.deliveredPackets.add(packetId);
    final progress = transfer.deliveredPackets.length / transfer.totalChunks;
    await _store.updateMessageProgress(transfer.messageId, progress);
    if (transfer.deliveredPackets.length >= transfer.totalChunks) {
      await _store.updateMessageStatus(
        transfer.messageId,
        MessageStatus.delivered,
      );
      _outboundFiles.remove(transferId);
      await _store.savePendingOutboundFiles(_outboundFiles);
      await _recordDiagnostic('file_send_complete', 'Plik dostarczony');
      setState(() => _status = 'Plik dostarczony');
      _showFeedback('Plik dostarczony.');
    } else {
      await _store.savePendingOutboundFiles(_outboundFiles);
      setState(() => _status = 'Wysyłam plik: ${(progress * 100).round()}%');
    }
  }
}
