import 'package:ble_communicator/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline app widget is constructible', () {
    expect(const OfflineChatApp(), isA<OfflineChatApp>());
  });
}
