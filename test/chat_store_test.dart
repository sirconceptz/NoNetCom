import 'package:ble_communicator/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  test('persists onboarding completion', () async {
    await prepareTestAppStorage('nonetcom-store-onboarding-test-');
    final store = ChatStore();
    await store.load();

    expect(store.onboardingSeen, isFalse);

    await store.markOnboardingSeen();

    final reloaded = ChatStore();
    await reloaded.load();
    expect(reloaded.onboardingSeen, isTrue);
  });

  test('warns when a verified contact changes public key', () async {
    await prepareTestAppStorage('nonetcom-store-contact-test-');
    final store = ChatStore();
    await store.load();

    await store.upsertContact(
      Contact(
        id: 'peer-a',
        name: 'Ala',
        remoteName: 'Ala',
        publicKey: 'old-key',
        lastSeen: DateTime(2026),
      ),
    );
    await store.verifyContact('peer-a');
    await store.upsertContact(
      Contact(
        id: 'peer-a',
        name: 'Ala zdalnie',
        remoteName: 'Ala zdalnie',
        publicKey: 'new-key',
        lastSeen: DateTime(2026, 1, 2),
        connected: true,
      ),
    );

    final contact = store.contact('peer-a')!;
    expect(contact.trustState, TrustState.keyChanged);
    expect(contact.publicKey, 'new-key');
    expect(contact.name, 'Ala');
    expect(contact.remoteName, 'Ala zdalnie');
    expect(contact.connected, isTrue);
  });

  test(
    'updates message delivery status and clamps transfer progress',
    () async {
      await prepareTestAppStorage('nonetcom-store-message-test-');
      final store = ChatStore();
      await store.load();
      await store.addMessage(
        ChatMessage(
          id: 'message-1',
          contactId: Contact.threadIdFor('peer-a'),
          text: 'Cześć',
          mine: true,
          sentAt: DateTime(2026),
          status: MessageStatus.sending,
          progress: 0,
        ),
      );

      await store.updateMessageProgress('message-1', 1.8);
      await store.updateMessageStatus('message-1', MessageStatus.delivered);

      expect(store.messages.single.progress, 1);
      expect(store.messages.single.status, MessageStatus.delivered);
    },
  );

  test('persists voice message metadata', () async {
    await prepareTestAppStorage('nonetcom-store-voice-test-');
    final store = ChatStore();
    await store.load();
    await store.addMessage(
      ChatMessage(
        id: 'voice-1',
        contactId: Contact.threadIdFor('peer-a'),
        text: 'Wiadomość głosowa',
        mine: true,
        sentAt: DateTime(2026),
        fileName: 'voice.m4a',
        fileSize: 2048,
        filePath: '/tmp/voice.m4a',
        attachmentType: MessageAttachmentType.voice,
        voiceDurationMs: 4200,
      ),
    );

    final reloaded = ChatStore();
    await reloaded.load();
    final message = reloaded.messages.single;

    expect(message.isVoiceMessage, isTrue);
    expect(message.voiceDurationMs, 4200);
    expect(message.filePath, '/tmp/voice.m4a');
  });

  test('persists pending file transfers and group delivery state', () async {
    await prepareTestAppStorage('nonetcom-store-pending-test-');
    final store = ChatStore();
    await store.load();

    await store.savePendingOutboundFiles({
      'transfer-1': OutboundFileTransfer(
        transferId: 'transfer-1',
        messageId: 'file-message-1',
        totalChunks: 3,
        deliveredPackets: {'transfer-1:0'},
      ),
    });
    await store.savePendingGroupDeliveries({
      'group-message-1:peer-a': OutboundGroupDelivery(
        messageId: 'group-message-1',
        totalPackets: 2,
      ),
    });

    final reloaded = ChatStore();
    await reloaded.load();

    expect(
      reloaded.pendingOutboundFiles['transfer-1']!.messageId,
      'file-message-1',
    );
    expect(
      reloaded.pendingOutboundFiles['transfer-1']!.deliveredPackets,
      contains('transfer-1:0'),
    );
    expect(
      reloaded.pendingGroupDeliveries['group-message-1:peer-a']!.totalPackets,
      2,
    );
  });

  test('exports and imports only trusted public contact data', () async {
    await prepareTestAppStorage('nonetcom-store-contact-backup-test-');
    final store = ChatStore();
    await store.load();
    await store.upsertContact(
      Contact(
        id: 'trusted-peer',
        name: 'Ala lokalnie',
        remoteName: 'Ala',
        publicKey: 'public-key',
        trustState: TrustState.verified,
        lastSeen: DateTime(2026),
      ),
    );
    await store.upsertContact(
      Contact(
        id: 'untrusted-peer',
        name: 'Ola',
        publicKey: 'other-public-key',
        lastSeen: DateTime(2026),
      ),
    );

    final backup = store.exportTrustedContactsBackup();

    expect(backup['type'], 'nonetcom-trusted-contacts');
    expect(backup.toString(), isNot(contains('private')));
    expect(backup['contactsCount'], 1);

    await prepareTestAppStorage('nonetcom-store-contact-restore-test-');
    final target = ChatStore();
    await target.load();
    final imported = await target.importTrustedContactsBackup(backup);

    expect(imported, 1);
    expect(target.contacts.single.id, 'trusted-peer');
    expect(target.contacts.single.name, 'Ala lokalnie');
    expect(target.contacts.single.publicKey, 'public-key');
    expect(target.contacts.single.trustState, TrustState.verified);
  });

  test('deleting a group removes only that group thread history', () async {
    await prepareTestAppStorage('nonetcom-store-group-test-');
    final store = ChatStore();
    await store.load();
    await store.upsertGroup(
      ChatGroup(
        id: 'group-a',
        name: 'Ekipa',
        memberIds: const ['peer-a', 'peer-b'],
        createdAt: DateTime(2026),
      ),
    );
    await store.addMessage(
      ChatMessage(
        id: 'group-message',
        contactId: ChatGroup.threadIdFor('group-a'),
        text: 'Grupowo',
        mine: true,
        sentAt: DateTime(2026),
      ),
    );
    await store.addMessage(
      ChatMessage(
        id: 'direct-message',
        contactId: Contact.threadIdFor('peer-a'),
        text: '1:1',
        mine: true,
        sentAt: DateTime(2026),
      ),
    );

    await store.deleteGroup('group-a');

    expect(store.groups, isEmpty);
    expect(store.messages.map((message) => message.id), ['direct-message']);
  });
}
