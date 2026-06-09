part of '../../main.dart';

class BleBridge {
  static const _methods = MethodChannel('skybridge/ble');
  static const _events = EventChannel('skybridge/ble/events');

  Stream<BleEvent> get events => _events
      .receiveBroadcastStream()
      .where((event) => event is Map<dynamic, dynamic>)
      .cast<Map<dynamic, dynamic>>()
      .map(BleEvent.fromPlatform);

  Future<void> start({required String displayName, required String publicKey}) {
    return _methods.invokeMethod<void>('start', {
      'displayName': displayName,
      'publicKey': publicKey,
    });
  }

  Future<void> scan() => _methods.invokeMethod<void>('scan');

  Future<void> stopBackground() =>
      _methods.invokeMethod<void>('stopBackground');

  Future<void> send(
    String peerId,
    String payload, {
    BlePriority priority = BlePriority.normal,
  }) {
    return _methods.invokeMethod<void>('send', {
      'peerId': peerId,
      'payload': payload,
      'priority': priority.value,
    });
  }
}

enum BlePriority {
  control(0),
  realtime(1),
  normal(2),
  bulk(3);

  const BlePriority(this.value);

  final int value;
}

class FileChooserBridge {
  static const _methods = MethodChannel('skybridge/files');

  static Future<PickedLocalFile?> pickFile() async {
    final result = await _methods.invokeMapMethod<String, dynamic>('pickFile');
    if (result == null) return null;
    return PickedLocalFile(
      path: result['path'] as String,
      name: result['name'] as String,
      size: result['size'] as int,
    );
  }
}

class PickedLocalFile {
  const PickedLocalFile({
    required this.path,
    required this.name,
    required this.size,
  });

  final String path;
  final String name;
  final int size;
}

enum BleEventKind { peer, payload, disconnected, status }

class BleEvent {
  const BleEvent({
    required this.kind,
    required this.peerId,
    this.name,
    this.publicKey,
    this.payload,
  });

  final BleEventKind kind;
  final String peerId;
  final String? name;
  final String? publicKey;
  final String? payload;

  factory BleEvent.fromPlatform(Map<dynamic, dynamic> map) {
    final type = map['type'] as String? ?? 'status';
    return BleEvent(
      kind: switch (type) {
        'peer' => BleEventKind.peer,
        'payload' => BleEventKind.payload,
        'disconnected' => BleEventKind.disconnected,
        _ => BleEventKind.status,
      },
      peerId: map['peerId'] as String? ?? '',
      name: map['name'] as String?,
      publicKey: map['publicKey'] as String?,
      payload: map['payload'] as String?,
    );
  }
}
