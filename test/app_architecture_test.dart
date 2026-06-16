import 'dart:convert';

import 'package:ble_communicator/main.dart';
import 'package:flutter/widgets.dart' hide DiagnosticLevel;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lifecycle coordinator forwards state changes', (tester) async {
    final states = <AppLifecycleState>[];
    final coordinator = AppLifecycleCoordinator((state) async {
      states.add(state);
    })..start();
    addTearDown(coordinator.dispose);

    coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
    coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();

    expect(states, [AppLifecycleState.paused, AppLifecycleState.resumed]);
  });

  test('diagnostics snapshot excludes message and file contents', () {
    const secretMessage = 'tajna tresc rozmowy';
    const fileName = 'sekretny-plan.pdf';
    final snapshot = DiagnosticsSnapshot(
      bluetoothRunning: true,
      scanning: false,
      contactsCount: 2,
      connectedContactsCount: 1,
      messagesCount: 5,
      pendingPackets: 0,
      outboundTransfers: 0,
      inboundTransfers: 0,
      status: 'gotowe bez tresci',
      events: const [],
    );

    final json = snapshot.toJson();
    final encoded = jsonEncode(json);

    expect(json['messagesCount'], 5);
    expect(json.containsKey('messages'), isFalse);
    expect(json.containsKey('files'), isFalse);
    expect(encoded, isNot(contains(secretMessage)));
    expect(encoded, isNot(contains(fileName)));
    expect(encoded, isNot(contains('privateKey')));
  });

  test(
    'diagnostics log section carries privacy marker without payload data',
    () {
      final snapshot = DiagnosticsSnapshot(
        bluetoothRunning: false,
        scanning: true,
        contactsCount: 1,
        connectedContactsCount: 0,
        messagesCount: 3,
        pendingPackets: 2,
        outboundTransfers: 1,
        inboundTransfers: 0,
        status: 'transfer trwa',
        events: [
          DiagnosticEntry(
            type: 'transport_retry',
            message: 'retry without plaintext',
            level: DiagnosticLevel.warning,
            createdAt: DateTime(2026),
          ),
        ],
      );

      final section = DiagnosticsReportService().asLogSection(snapshot);

      expect(section, contains('diagnosticsIncluded'));
      expect(section, contains('Raport nie zawiera'));
      expect(section, isNot(contains('cipherText')));
      expect(section, isNot(contains('nonce')));
      expect(section, isNot(contains('mac')));
    },
  );
}
