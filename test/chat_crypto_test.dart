import 'dart:convert';

import 'package:ble_communicator/main.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  test(
    'E2EE v2 derives directional keys and authenticates packet context',
    () async {
      await prepareTestAppStorage('nonetcom-crypto-v2-test-');
      final algorithm = X25519();
      final alicePair = await algorithm.newKeyPair();
      final bobPair = await algorithm.newKeyPair();
      final alice = ChatCrypto(identity: alicePair);
      final bob = ChatCrypto(identity: bobPair);
      await alice.loadOrCreate();
      await bob.loadOrCreate();
      final alicePublic = base64Encode(
        (await alicePair.extractPublicKey()).bytes,
      );
      final bobPublic = base64Encode((await bobPair.extractPublicKey()).bytes);

      final encrypted = await alice.encryptText(
        peerPublicKey: bobPublic,
        text: 'tajna wiadomość',
        packetId: 'packet-1',
      );

      expect(encrypted.protocolVersion, ChatCrypto.protocolVersion);
      expect(encrypted.counter, 1);
      expect(
        await bob.decryptText(
          peerPublicKey: alicePublic,
          packetId: 'packet-1',
          protocolVersion: encrypted.protocolVersion,
          counter: encrypted.counter,
          nonce: encrypted.nonce,
          cipherText: encrypted.cipherText,
          mac: encrypted.mac,
        ),
        'tajna wiadomość',
      );
      await expectLater(
        bob.decryptText(
          peerPublicKey: alicePublic,
          packetId: 'zmieniony-packet',
          protocolVersion: encrypted.protocolVersion,
          counter: encrypted.counter,
          nonce: encrypted.nonce,
          cipherText: encrypted.cipherText,
          mac: encrypted.mac,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await expectLater(
        bob.decryptText(
          peerPublicKey: bobPublic,
          packetId: 'packet-1',
          protocolVersion: encrypted.protocolVersion,
          counter: encrypted.counter,
          nonce: encrypted.nonce,
          cipherText: encrypted.cipherText,
          mac: encrypted.mac,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await expectLater(
        bob.decryptText(
          peerPublicKey: alicePublic,
          packetId: 'packet-1',
          protocolVersion: ChatCrypto.protocolVersion + 1,
          counter: encrypted.counter,
          nonce: encrypted.nonce,
          cipherText: encrypted.cipherText,
          mac: encrypted.mac,
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'E2EE v2 persists replay counters and increments send counters',
    () async {
      await prepareTestAppStorage('nonetcom-crypto-replay-test-');
      final algorithm = X25519();
      final alicePair = await algorithm.newKeyPair();
      final bobPair = await algorithm.newKeyPair();
      final alice = ChatCrypto(identity: alicePair);
      final bob = ChatCrypto(identity: bobPair);
      await alice.loadOrCreate();
      await bob.loadOrCreate();
      final alicePublic = base64Encode(
        (await alicePair.extractPublicKey()).bytes,
      );
      final bobPublic = base64Encode((await bobPair.extractPublicKey()).bytes);

      final first = await alice.encryptText(
        peerPublicKey: bobPublic,
        text: 'pierwsza',
        packetId: 'packet-1',
      );
      final second = await alice.encryptText(
        peerPublicKey: bobPublic,
        text: 'druga',
        packetId: 'packet-2',
      );
      expect(second.counter, first.counter + 1);

      expect(bob.hasSeenCounter(alicePublic, first.counter), isFalse);
      await bob.markCounterSeen(alicePublic, first.counter);
      final reloadedBob = ChatCrypto(identity: bobPair);
      await reloadedBob.loadOrCreate();
      expect(reloadedBob.hasSeenCounter(alicePublic, first.counter), isTrue);
    },
  );

  test('E2EE replay window retains only the latest 512 counters', () async {
    await prepareTestAppStorage('nonetcom-crypto-window-test-');
    final algorithm = X25519();
    final alicePair = await algorithm.newKeyPair();
    final bobPair = await algorithm.newKeyPair();
    final alicePublic = base64Encode(
      (await alicePair.extractPublicKey()).bytes,
    );
    final bob = ChatCrypto(identity: bobPair);
    await bob.loadOrCreate();

    for (var counter = 1; counter <= 520; counter += 1) {
      await bob.markCounterSeen(alicePublic, counter);
    }

    expect(bob.hasSeenCounter(alicePublic, 1), isFalse);
    expect(bob.hasSeenCounter(alicePublic, 8), isFalse);
    expect(bob.hasSeenCounter(alicePublic, 9), isTrue);
    expect(bob.hasSeenCounter(alicePublic, 520), isTrue);
  });
}
