import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ble_communicator/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  test(
    'splits payload into frames and reassembles them out of order',
    () async {
      await prepareTestAppStorage('nonetcom-transport-test-');
      final sender = ReliableTransport();
      final receiver = ReliableTransport();
      addTearDown(sender.dispose);
      addTearDown(receiver.dispose);
      await sender.load();
      await receiver.load();

      final payload = jsonEncode({
        'type': 'secure',
        'packetId': 'message-1',
        'cipherText': 'x' * 420,
      });
      final envelope = sender.enqueue('peer-a', payload);

      expect(envelope.id, 'message-1');
      expect(envelope.frames.length, greaterThan(1));
      expect(sender.pendingCount, 1);

      String? completed;
      for (final frame in envelope.frames.reversed) {
        completed = receiver.acceptFrame(frame.toJson()) ?? completed;
      }

      expect(completed, payload);
    },
  );

  test('reassembles frames with duplicates and shuffled delivery', () async {
    await prepareTestAppStorage('nonetcom-transport-fuzz-test-');
    final sender = ReliableTransport();
    final receiver = ReliableTransport();
    addTearDown(sender.dispose);
    addTearDown(receiver.dispose);
    await sender.load();
    await receiver.load();

    final payload = jsonEncode({
      'type': 'secure',
      'packetId': 'message-fuzz',
      'cipherText': 'z' * 1500,
    });
    final envelope = sender.enqueue('peer-a', payload);
    final frames = [
      ...envelope.frames,
      envelope.frames[1],
      envelope.frames.first,
    ]..shuffle(Random(42));

    String? completed;
    for (final frame in frames.take(frames.length - 2)) {
      completed = receiver.acceptFrame(frame.toJson()) ?? completed;
    }
    expect(completed, isNull);

    for (final frame in frames.skip(frames.length - 2)) {
      completed = receiver.acceptFrame(frame.toJson()) ?? completed;
    }
    expect(completed, payload);
  });

  test(
    'persists pending outbox and clears delivered packet after reload',
    () async {
      await prepareTestAppStorage('nonetcom-transport-persist-test-');
      final transport = ReliableTransport();
      await transport.load();
      final envelope = transport.enqueue(
        'peer-a',
        jsonEncode({'type': 'secure', 'packetId': 'packet-persist'}),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      transport.dispose();

      final reloaded = ReliableTransport();
      addTearDown(reloaded.dispose);
      await reloaded.load();

      expect(reloaded.pendingFor('peer-a'), hasLength(1));
      expect(reloaded.pendingFor('peer-a').single.packetId, envelope.packetId);

      final delivered = reloaded.markDelivered(envelope.packetId);
      expect(delivered, isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final emptyReload = ReliableTransport();
      addTearDown(emptyReload.dispose);
      await emptyReload.load();
      expect(emptyReload.pendingCount, 0);
    },
  );

  test('drops corrupted outbox file on load', () async {
    final directory = await prepareTestAppStorage(
      'nonetcom-transport-corrupt-test-',
    );
    final queueDir = Directory('${directory.path}/NoNetCom')
      ..createSync(recursive: true);
    final outboxFile = File('${queueDir.path}/nonetcom-transport-outbox.json')
      ..writeAsStringSync('not-json');

    final transport = ReliableTransport();
    addTearDown(transport.dispose);
    await transport.load();

    expect(transport.pendingCount, 0);
    expect(outboxFile.existsSync(), isFalse);
  });

  test(
    'marks individual frame ACKs and resets fully acked frames on retry',
    () async {
      await prepareTestAppStorage('nonetcom-transport-ack-test-');
      final transport = ReliableTransport();
      addTearDown(transport.dispose);
      await transport.load();

      final envelope = transport.enqueue(
        'peer-a',
        jsonEncode({
          'type': 'secure',
          'packetId': 'packet-ack',
          'body': 'y' * 420,
        }),
      );

      transport.markFrameAcked('peer-a', envelope.frames.first.frameId);
      expect(envelope.frames.first.acked, isTrue);
      expect(envelope.frames.skip(1).every((frame) => frame.acked), isFalse);

      transport.markFrameAcked('other-peer', envelope.frames.last.frameId);
      expect(envelope.frames.last.acked, isFalse);

      for (final frame in envelope.frames.skip(1)) {
        transport.markFrameAcked('peer-a', frame.frameId);
      }
      expect(envelope.frames.every((frame) => frame.acked), isTrue);

      final failed = transport.registerAttempt(envelope.id);

      expect(failed, isFalse);
      expect(envelope.attempts, 1);
      expect(envelope.frames.every((frame) => !frame.acked), isTrue);
    },
  );

  test('marks envelope failed after send attempts are exhausted', () async {
    await prepareTestAppStorage('nonetcom-transport-retry-test-');
    final transport = ReliableTransport();
    addTearDown(transport.dispose);
    await transport.load();
    final envelope = transport.enqueue(
      'peer-a',
      jsonEncode({'type': 'secure', 'packetId': 'packet-retry'}),
    );

    var failed = false;
    for (var attempt = 0; attempt < 6; attempt += 1) {
      failed = transport.registerAttempt(envelope.id);
    }

    expect(failed, isTrue);
    expect(envelope.failed, isTrue);
    expect(transport.pendingCount, 0);
    expect(transport.pendingFor('peer-a'), isEmpty);
  });

  test('discards stale live voice packets without touching chat', () async {
    await prepareTestAppStorage('nonetcom-transport-live-test-');
    final transport = ReliableTransport();
    addTearDown(transport.dispose);
    await transport.load();
    transport.enqueue(
      'peer-a',
      jsonEncode({
        'type': 'secure',
        'packetId': 'live-audio:session-1:segment-1',
      }),
    );
    transport.enqueue(
      'peer-a',
      jsonEncode({'type': 'secure', 'packetId': 'message-1'}),
    );

    transport.discardWhere(
      (envelope) => envelope.packetId.startsWith('live-audio:'),
    );

    expect(transport.pendingFor('peer-a'), hasLength(1));
    expect(transport.pendingFor('peer-a').single.packetId, 'message-1');
  });

  test(
    'removes delivered packets and exposes transfer id for file ACKs',
    () async {
      await prepareTestAppStorage('nonetcom-transport-delivery-test-');
      final transport = ReliableTransport();
      addTearDown(transport.dispose);
      await transport.load();
      transport.enqueue(
        'peer-a',
        jsonEncode({
          'type': 'secure',
          'packetId': 'transfer-1:0',
          'transferId': 'transfer-1',
        }),
      );

      final delivered = transport.markDelivered('transfer-1:0');

      expect(delivered, isNotNull);
      expect(delivered!.transferId, 'transfer-1');
      expect(transport.pendingCount, 0);
    },
  );

  test('clear removes in-memory and persisted outbox', () async {
    await prepareTestAppStorage('nonetcom-transport-clear-test-');
    final transport = ReliableTransport();
    await transport.load();
    transport.enqueue(
      'peer-a',
      jsonEncode({'type': 'secure', 'packetId': 'packet-clear'}),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));

    await transport.clear();
    transport.dispose();

    final reloaded = ReliableTransport();
    addTearDown(reloaded.dispose);
    await reloaded.load();

    expect(reloaded.pendingCount, 0);
  });
}
