import 'dart:convert';

import 'package:ble_communicator/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final publicKey = base64Encode(List<int>.generate(32, (index) => index));

  test('verification QR round-trips identity data', () {
    final payload = VerificationQrPayload(
      profileName: 'Mateusz',
      publicKey: publicKey,
    );

    final decoded = VerificationQrPayload.tryParse(payload.encode());

    expect(decoded, isNotNull);
    expect(decoded!.profileName, 'Mateusz');
    expect(decoded.publicKey, publicKey);
    expect(decoded.safetyCode, payload.safetyCode);
  });

  test('verification QR rejects unrelated payloads', () {
    expect(
      VerificationQrPayload.tryParse(
        jsonEncode({'app': 'OtherApp', 'publicKey': publicKey}),
      ),
      isNull,
    );
    expect(VerificationQrPayload.tryParse('not-json'), isNull);
    expect(
      VerificationQrPayload.tryParse(
        jsonEncode({
          'app': 'NoNetCom',
          'type': 'identity-verification',
          'version': 99,
          'profileName': 'Mateusz',
          'publicKey': publicKey,
        }),
      ),
      isNull,
    );
    expect(
      VerificationQrPayload.tryParse(
        jsonEncode({
          'app': 'NoNetCom',
          'type': 'identity-verification',
          'version': 1,
          'profileName': 'Mateusz',
          'publicKey': 'not-base64',
        }),
      ),
      isNull,
    );
    expect(
      VerificationQrPayload.tryParse(
        jsonEncode({
          'app': 'NoNetCom',
          'type': 'identity-verification',
          'version': 1,
          'profileName': '   ',
          'publicKey': publicKey,
        }),
      ),
      isNull,
    );
  });

  test('verification succeeds only for the stored contact key', () {
    final payload = VerificationQrPayload(
      profileName: 'Kontakt',
      publicKey: publicKey,
    );
    final matchingContact = Contact(
      id: 'matching',
      name: 'Kontakt',
      publicKey: publicKey,
      lastSeen: DateTime(2026),
    );
    final otherContact = Contact(
      id: 'other',
      name: 'Inny kontakt',
      publicKey: base64Encode(List<int>.filled(32, 7)),
      lastSeen: DateTime(2026),
    );

    expect(payload.matches(matchingContact), isTrue);
    expect(payload.matches(otherContact), isFalse);
  });
}
