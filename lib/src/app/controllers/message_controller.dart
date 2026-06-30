// ignore_for_file: invalid_use_of_protected_member

part of '../../../main.dart';

extension _MessageController on _ChatShellState {
  Future<void> _sendMessage() async {
    final group = _selectedGroup;
    if (group != null) {
      await _sendGroupMessage(group);
      return;
    }

    final contact = _selectedContact;
    final text = _messageController.text.trim();
    if (contact == null || text.isEmpty) {
      return;
    }
    if (contact.publicKey == null) {
      setState(
        () => _status =
            'Czekam na bezpieczne połączenie. Zostaw oba telefony blisko siebie.',
      );
      _showFeedback(
        'Czekam na połączenie z tą osobą. Wiadomość wyślesz, gdy będzie gotowe.',
      );
      await _sendHello(contact.id);
      return;
    }

    final messageId = _newId();
    final queued = await _queueSecurePacket(
      contact: contact,
      packetId: messageId,
      clearPayload: {'kind': 'text', 'messageId': messageId, 'text': text},
    );
    await _store.addMessage(
      ChatMessage(
        id: messageId,
        contactId: contact.threadId,
        text: text,
        mine: true,
        sentAt: DateTime.now(),
        status: MessageStatus.sending,
      ),
    );
    _messageController.clear();
    await _sendQueuedEnvelope(queued);
    await _recordDiagnostic('message_queued', 'Wiadomość dodana do kolejki');
    setState(() => _status = 'Wysyłam wiadomość');
  }

  Future<void> _sendGroupMessage(ChatGroup group) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final members = group.memberIds
        .map(_store.contact)
        .whereType<Contact>()
        .where((contact) => contact.publicKey != null)
        .toList();
    if (members.isEmpty) {
      setState(() => _status = 'W grupie nie ma teraz gotowych osób');
      _showFeedback('Żadna osoba w grupie nie ma teraz gotowego połączenia.');
      return;
    }

    final messageId = _newId();
    final pendingPackets = <String>{};
    final envelopes = <OutboundEnvelope>[];
    for (final contact in members) {
      final packetId = '$messageId:${contact.id}';
      pendingPackets.add(packetId);
      final queued = await _queueSecurePacket(
        contact: contact,
        packetId: packetId,
        clearPayload: {
          'kind': 'groupText',
          'groupId': group.id,
          'groupName': group.name,
          'memberIds': group.memberIds,
          'messageId': messageId,
          'senderName': _store.profileName,
          'text': text,
        },
      );
      envelopes.add(queued);
    }
    _groupDeliveries.addAll({
      for (final packetId in pendingPackets)
        packetId: OutboundGroupDelivery(
          messageId: messageId,
          totalPackets: pendingPackets.length,
        ),
    });
    await _store.savePendingGroupDeliveries(_groupDeliveries);
    await _store.addMessage(
      ChatMessage(
        id: messageId,
        contactId: group.threadId,
        text: text,
        mine: true,
        sentAt: DateTime.now(),
        status: MessageStatus.sending,
        progress: 0,
        senderName: _store.profileName,
      ),
    );
    _messageController.clear();
    for (final envelope in envelopes) {
      await _sendQueuedEnvelope(envelope);
    }
    await _recordDiagnostic(
      'group_message_queued',
      'Wiadomość grupowa w kolejce',
    );
    setState(() => _status = 'Wysyłam wiadomość do grupy');
  }

  Future<void> _handleSecurePayload(
    String peerId,
    Contact contact,
    String packetId,
    Map<String, dynamic> payload,
  ) async {
    switch (payload['kind']) {
      case 'text':
        await _store.addMessage(
          ChatMessage(
            id: payload['messageId'] as String,
            contactId: Contact.threadIdFor(peerId),
            text: payload['text'] as String,
            mine: false,
            sentAt: DateTime.now(),
            status: MessageStatus.delivered,
          ),
        );
        await _recordDiagnostic('message_received', 'Odebrano wiadomość');
        _selectedThreadId ??= Contact.threadIdFor(peerId);
        await _notifyIncomingMessage(
          threadId: Contact.threadIdFor(peerId),
          title: contact.name,
          body: payload['text'] as String,
          messageId: payload['messageId'] as String,
        );
        setState(() => _status = 'Nowa wiadomość od ${contact.name}');
      case 'groupText':
        await _acceptGroupMessage(peerId, contact, payload);
      case 'fileOffer':
        await _acceptFileOffer(peerId, payload);
      case 'fileChunk':
        await _acceptFileChunk(peerId, payload);
      case 'fileComplete':
        await _completeInboundFile(peerId, payload);
      case 'liveVoiceInvite':
      case 'liveVoiceAccept':
      case 'liveVoiceEnd':
      case 'liveVoiceSegment':
        await _handleLiveVoicePayload(peerId, contact, payload);
      case 'connectionCheck':
        await _recordDiagnostic(
          'connection_check_received',
          'Odebrano test połączenia',
        );
        setState(() => _status = 'Połączenie z ${contact.name} działa');
    }
    await _sendDeliveryAck(peerId, packetId);
  }

  Future<void> _acceptGroupMessage(
    String peerId,
    Contact sender,
    Map<String, dynamic> payload,
  ) async {
    final groupId = payload['groupId'] as String;
    final memberIds = ((payload['memberIds'] as List<dynamic>?) ?? [])
        .whereType<String>()
        .where((id) => id != peerId)
        .take(_maxGroupMembers - 1)
        .toList();
    final mergedMembers = <String>{
      peerId,
      ...memberIds,
    }.take(_maxGroupMembers).toList();
    final group = ChatGroup(
      id: groupId,
      name: (payload['groupName'] as String?)?.trim().isNotEmpty == true
          ? payload['groupName'] as String
          : 'Grupa',
      memberIds: mergedMembers,
      createdAt: DateTime.now(),
    );
    await _store.upsertGroup(group);
    await _store.addMessage(
      ChatMessage(
        id: payload['messageId'] as String,
        contactId: group.threadId,
        text: payload['text'] as String,
        mine: false,
        sentAt: DateTime.now(),
        status: MessageStatus.delivered,
        senderName: (payload['senderName'] as String?) ?? sender.name,
      ),
    );
    _selectedThreadId ??= group.threadId;
    await _recordDiagnostic(
      'group_message_received',
      'Odebrano wiadomość grupową',
    );
    await _notifyIncomingMessage(
      threadId: group.threadId,
      title: group.name,
      body:
          '${(payload['senderName'] as String?) ?? sender.name}: ${payload['text']}',
      messageId: payload['messageId'] as String,
    );
    setState(() => _status = 'Nowa wiadomość w grupie ${group.name}');
  }

  Future<void> _notifyIncomingMessage({
    required String threadId,
    required String title,
    required String body,
    required String messageId,
  }) async {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final threadOpen =
        lifecycle == AppLifecycleState.resumed && _selectedThreadId == threadId;
    if (threadOpen) return;
    await _notifications.showMessage(
      title: title,
      body: body,
      messageId: messageId,
      threadId: threadId,
    );
  }

  Future<void> _markGroupPacketDelivered(String packetId) async {
    final delivery = _groupDeliveries[packetId];
    if (delivery == null) return;
    _groupDeliveries.remove(packetId);
    await _store.savePendingGroupDeliveries(_groupDeliveries);
    final remaining = _groupDeliveries.values
        .where((item) => item.messageId == delivery.messageId)
        .length;
    final delivered = delivery.totalPackets - remaining;
    await _store.updateMessageProgress(
      delivery.messageId,
      delivered / delivery.totalPackets,
    );
    if (remaining == 0) {
      await _store.updateMessageStatus(
        delivery.messageId,
        MessageStatus.delivered,
      );
      setState(() => _status = 'Wiadomość grupowa dostarczona');
      return;
    }
    setState(() => _status = 'Czekam na potwierdzenia z grupy');
  }
}
