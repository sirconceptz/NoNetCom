import 'package:ble_communicator/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contact initials use up to two trimmed name parts', () {
    expect(
      Contact(
        id: 'peer-a',
        name: '  Ala   Kowalska  ',
        lastSeen: DateTime(2026),
      ).initials,
      'AK',
    );
    expect(
      Contact(id: 'peer-b', name: 'Łukasz', lastSeen: DateTime(2026)).initials,
      'Ł',
    );
  });

  test('message json falls back to safe enum defaults', () {
    final message = ChatMessage.fromJson({
      'id': 'message-1',
      'contactId': Contact.threadIdFor('peer-a'),
      'text': 'Czesc',
      'mine': true,
      'sentAt': DateTime(2026).toIso8601String(),
      'status': 'future-status',
      'attachmentType': 'future-attachment',
    });

    expect(message.status, MessageStatus.delivered);
    expect(message.attachmentType, MessageAttachmentType.file);
  });

  test('voice message requires voice attachment type', () {
    final fileMessage = ChatMessage(
      id: 'file',
      contactId: Contact.threadIdFor('peer-a'),
      text: 'plik',
      mine: true,
      sentAt: DateTime(2026),
      fileName: 'audio.m4a',
      attachmentType: MessageAttachmentType.file,
    );
    final voiceMessage = ChatMessage(
      id: 'voice',
      contactId: Contact.threadIdFor('peer-a'),
      text: 'glos',
      mine: true,
      sentAt: DateTime(2026),
      fileName: 'voice.m4a',
      attachmentType: MessageAttachmentType.voice,
    );

    expect(fileMessage.isVoiceMessage, isFalse);
    expect(voiceMessage.isVoiceMessage, isTrue);
  });

  test('group initials fall back for blank names', () {
    expect(
      ChatGroup(
        id: 'group-a',
        name: '  ',
        memberIds: const [],
        createdAt: DateTime(2026),
      ).initials,
      'G',
    );
    expect(
      ChatGroup(
        id: 'group-b',
        name: 'Ekipa Offline',
        memberIds: const [],
        createdAt: DateTime(2026),
      ).initials,
      'EO',
    );
  });
}
