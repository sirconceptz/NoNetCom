part of '../../main.dart';

class ReliableTransport {
  static const _outboxFileName = 'nonetcom-transport-outbox.json';

  final Map<String, OutboundEnvelope> _outbound = {};
  final Map<String, InboundEnvelope> _inbound = {};
  File? _outboxFile;
  Timer? _saveDebounce;

  int get pendingCount => _outbound.values.where((item) => !item.failed).length;

  Future<void> load() async {
    final queueDir = await _queueDirectory();
    if (!queueDir.existsSync()) {
      queueDir.createSync(recursive: true);
    }
    _outboxFile = File('${queueDir.path}/$_outboxFileName');
    final file = _outboxFile!;
    if (!file.existsSync()) return;
    final String raw;
    final List<dynamic> decoded;
    try {
      raw = await file.readAsString();
      if (raw.trim().isEmpty) return;
      decoded = jsonDecode(raw) as List<dynamic>;
    } on FormatException {
      await file.delete();
      return;
    } on FileSystemException {
      return;
    }
    _outbound
      ..clear()
      ..addEntries(
        decoded.map((json) {
          final envelope = OutboundEnvelope.fromJson(
            json as Map<String, dynamic>,
          );
          return MapEntry(envelope.id, envelope);
        }),
      );
  }

  OutboundEnvelope enqueue(String peerId, String payload) {
    final envelope = OutboundEnvelope.create(peerId: peerId, payload: payload);
    _outbound[envelope.id] = envelope;
    _scheduleSave();
    return envelope;
  }

  List<OutboundEnvelope> pendingFor(String? peerId) => _outbound.values
      .where((envelope) => peerId == null || envelope.peerId == peerId)
      .where((envelope) => !envelope.failed)
      .toList();

  bool registerAttempt(String envelopeId) {
    final envelope = _outbound[envelopeId];
    if (envelope == null) return true;
    envelope.attempts += 1;
    if (envelope.attempts > _maxSendAttempts) {
      envelope.failed = true;
      _scheduleSave();
      return true;
    }
    if (envelope.frames.every((frame) => frame.acked)) {
      for (final frame in envelope.frames) {
        frame.acked = false;
      }
    }
    _scheduleSave();
    return false;
  }

  void markFrameAcked(String peerId, String frameId) {
    for (final envelope in _outbound.values.where(
      (envelope) => envelope.peerId == peerId,
    )) {
      for (final frame in envelope.frames.where(
        (frame) => frame.frameId == frameId,
      )) {
        frame.acked = true;
      }
    }
    _scheduleSave();
  }

  OutboundEnvelope? markDelivered(String packetId) {
    final envelope = _outbound.remove(packetId);
    _scheduleSave();
    return envelope;
  }

  void discardWhere(bool Function(OutboundEnvelope envelope) test) {
    _outbound.removeWhere((_, envelope) => test(envelope));
    _scheduleSave();
  }

  Future<void> clear() async {
    _saveDebounce?.cancel();
    _outbound.clear();
    _inbound.clear();
    final file = _outboxFile;
    if (file != null && file.existsSync()) {
      await file.delete();
    }
  }

  void dispose() {
    _saveDebounce?.cancel();
  }

  String? acceptFrame(Map<String, dynamic> map) {
    final envelopeId = map['envelopeId'] as String;
    final inbound = _inbound.putIfAbsent(
      envelopeId,
      () => InboundEnvelope(total: map['total'] as int),
    );
    inbound.chunks[map['index'] as int] = map['data'] as String;
    if (!inbound.complete) {
      return null;
    }
    _inbound.remove(envelopeId);
    return utf8.decode(base64Decode(inbound.joined));
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_save()),
    );
  }

  Future<void> _save() async {
    final file = _outboxFile;
    if (file == null) return;
    final items = _outbound.values
        .where((envelope) => !envelope.failed)
        .map((envelope) => envelope.toJson())
        .toList();
    await file.writeAsString(jsonEncode(items), flush: true);
  }

  Future<Directory> _queueDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return Directory('${directory.path}/NoNetCom');
    } on MissingPluginException {
      return Directory('${Directory.systemTemp.path}/NoNetCom');
    }
  }
}

class OutboundEnvelope {
  OutboundEnvelope({
    required this.id,
    required this.peerId,
    required this.frames,
    required this.packetId,
    this.transferId,
    this.attempts = 0,
    this.failed = false,
  });

  final String id;
  final String peerId;
  final List<OutboundFrame> frames;
  final String packetId;
  final String? transferId;
  int attempts;
  bool failed;

  factory OutboundEnvelope.create({
    required String peerId,
    required String payload,
  }) {
    final envelopeId = _newId();
    final encoded = base64Encode(utf8.encode(payload));
    final chunks = <String>[];
    for (var offset = 0; offset < encoded.length; offset += _framePayloadSize) {
      chunks.add(
        encoded.substring(
          offset,
          min(offset + _framePayloadSize, encoded.length),
        ),
      );
    }
    final payloadMap = jsonDecode(payload) as Map<String, dynamic>;
    final packetId =
        payloadMap['packetId'] as String? ??
        payloadMap['messageId'] as String? ??
        envelopeId;
    return OutboundEnvelope(
      id: packetId,
      peerId: peerId,
      packetId: packetId,
      transferId: payloadMap['transferId'] as String?,
      frames: [
        for (var index = 0; index < chunks.length; index += 1)
          OutboundFrame(
            frameId: '$envelopeId:$index',
            envelopeId: envelopeId,
            index: index,
            total: chunks.length,
            data: chunks[index],
          ),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'peerId': peerId,
    'packetId': packetId,
    'transferId': transferId,
    'attempts': attempts,
    'failed': failed,
    'frames': frames.map((frame) => frame.toJson()).toList(),
  };

  factory OutboundEnvelope.fromJson(Map<String, dynamic> json) =>
      OutboundEnvelope(
        id: json['id'] as String,
        peerId: json['peerId'] as String,
        packetId: json['packetId'] as String,
        transferId: json['transferId'] as String?,
        attempts: json['attempts'] as int? ?? 0,
        failed: json['failed'] as bool? ?? false,
        frames: (json['frames'] as List<dynamic>)
            .map(
              (frame) => OutboundFrame.fromJson(frame as Map<String, dynamic>),
            )
            .toList(),
      );
}

class OutboundFrame {
  OutboundFrame({
    required this.frameId,
    required this.envelopeId,
    required this.index,
    required this.total,
    required this.data,
    this.acked = false,
  });

  final String frameId;
  final String envelopeId;
  final int index;
  final int total;
  final String data;
  bool acked;

  Map<String, dynamic> toJson() => {
    'type': 'frame',
    'frameId': frameId,
    'envelopeId': envelopeId,
    'index': index,
    'total': total,
    'data': data,
    'acked': acked,
  };

  factory OutboundFrame.fromJson(Map<String, dynamic> json) => OutboundFrame(
    frameId: json['frameId'] as String,
    envelopeId: json['envelopeId'] as String,
    index: json['index'] as int,
    total: json['total'] as int,
    data: json['data'] as String,
    acked: false,
  );
}

class InboundEnvelope {
  InboundEnvelope({required this.total});

  final int total;
  final Map<int, String> chunks = {};

  bool get complete => chunks.length == total;

  String get joined => [
    for (var index = 0; index < total; index += 1) chunks[index] ?? '',
  ].join();
}

class OutboundFileTransfer {
  OutboundFileTransfer({
    required this.transferId,
    required this.messageId,
    required this.totalChunks,
    Set<String>? deliveredPackets,
  }) : deliveredPackets = deliveredPackets ?? {};

  final String transferId;
  final String messageId;
  final int totalChunks;
  final Set<String> deliveredPackets;

  Map<String, dynamic> toJson() => {
    'transferId': transferId,
    'messageId': messageId,
    'totalChunks': totalChunks,
    'deliveredPackets': deliveredPackets.toList(),
  };

  factory OutboundFileTransfer.fromJson(Map<String, dynamic> json) =>
      OutboundFileTransfer(
        transferId: json['transferId'] as String,
        messageId: json['messageId'] as String,
        totalChunks: json['totalChunks'] as int,
        deliveredPackets: ((json['deliveredPackets'] as List<dynamic>?) ?? [])
            .whereType<String>()
            .toSet(),
      );
}

class OutboundGroupDelivery {
  OutboundGroupDelivery({required this.messageId, required this.totalPackets});

  final String messageId;
  final int totalPackets;

  Map<String, dynamic> toJson() => {
    'messageId': messageId,
    'totalPackets': totalPackets,
  };

  factory OutboundGroupDelivery.fromJson(Map<String, dynamic> json) =>
      OutboundGroupDelivery(
        messageId: json['messageId'] as String,
        totalPackets: json['totalPackets'] as int? ?? 1,
      );
}

class InboundFileTransfer {
  InboundFileTransfer({
    required this.transferId,
    required this.messageId,
    required this.peerId,
    required this.name,
    required this.size,
    required this.totalChunks,
    required this.path,
    required this.file,
    this.attachmentType = MessageAttachmentType.file,
    this.voiceDurationMs,
  });

  final String transferId;
  final String messageId;
  final String peerId;
  final String name;
  final int size;
  final int totalChunks;
  final String path;
  final RandomAccessFile file;
  final MessageAttachmentType attachmentType;
  final int? voiceDurationMs;
  final Set<int> receivedChunks = {};
  bool completeRequested = false;

  bool get isComplete => receivedChunks.length >= totalChunks;

  int get percent => ((receivedChunks.length / totalChunks) * 100).round();
}
