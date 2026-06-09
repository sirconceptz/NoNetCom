import 'package:ble_communicator/main.dart';
import 'package:flutter/widgets.dart';
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
    final snapshot = DiagnosticsSnapshot(
      bluetoothRunning: true,
      scanning: false,
      contactsCount: 2,
      connectedContactsCount: 1,
      messagesCount: 5,
      pendingPackets: 0,
      outboundTransfers: 0,
      inboundTransfers: 0,
      status: 'gotowe',
      events: const [],
    );

    final json = snapshot.toJson();

    expect(json['messagesCount'], 5);
    expect(json.containsKey('messages'), isFalse);
    expect(json.containsKey('files'), isFalse);
  });
}
