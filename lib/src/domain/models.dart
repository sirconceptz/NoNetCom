part of '../../main.dart';

class VerificationQrPayload {
  const VerificationQrPayload({
    required this.profileName,
    required this.publicKey,
  });

  static const int version = 1;
  static const String type = 'identity-verification';

  final String profileName;
  final String publicKey;

  String get safetyCode => ChatCrypto.fingerprintCode(publicKey);

  String encode() => jsonEncode({
    'app': _serviceName,
    'type': type,
    'version': version,
    'profileName': profileName,
    'publicKey': publicKey,
  });

  bool matches(Contact contact) =>
      contact.publicKey != null && contact.publicKey == publicKey;

  static VerificationQrPayload? tryParse(String rawValue) {
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, dynamic> ||
          decoded['app'] != _serviceName ||
          decoded['type'] != type ||
          decoded['version'] != version) {
        return null;
      }
      final profileName = decoded['profileName'];
      final publicKey = decoded['publicKey'];
      if (profileName is! String ||
          profileName.trim().isEmpty ||
          publicKey is! String ||
          publicKey.isEmpty) {
        return null;
      }
      base64Decode(publicKey);
      return VerificationQrPayload(
        profileName: profileName.trim(),
        publicKey: publicKey,
      );
    } on FormatException {
      return null;
    }
  }
}

class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.lastSeen,
    this.remoteName,
    this.publicKey,
    this.trustState = TrustState.unverified,
    this.connected = false,
  });

  final String id;
  final String name;
  final String? remoteName;
  final String? publicKey;
  final TrustState trustState;
  final DateTime lastSeen;
  final bool connected;

  static String threadIdFor(String id) => 'contact:$id';

  String get threadId => threadIdFor(id);

  String get trustLabel {
    if (publicKey == null) return 'brak klucza';
    return switch (trustState) {
      TrustState.unverified => 'niezweryfikowany',
      TrustState.verified => 'zweryfikowany',
      TrustState.keyChanged => 'klucz zmieniony',
    };
  }

  String get safetyCode {
    if (publicKey == null) return '---- ---- ----';
    return ChatCrypto.fingerprintCode(publicKey!);
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    return parts
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
  }

  Contact copyWith({
    String? name,
    String? remoteName,
    String? publicKey,
    DateTime? lastSeen,
    TrustState? trustState,
    bool? connected,
  }) => Contact(
    id: id,
    name: name ?? this.name,
    remoteName: remoteName ?? this.remoteName,
    lastSeen: lastSeen ?? this.lastSeen,
    publicKey: publicKey ?? this.publicKey,
    trustState: trustState ?? this.trustState,
    connected: connected ?? this.connected,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'remoteName': remoteName,
    'publicKey': publicKey,
    'trustState': trustState.name,
    'lastSeen': lastSeen.toIso8601String(),
    'connected': connected,
  };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    id: json['id'] as String,
    name: json['name'] as String,
    remoteName: json['remoteName'] as String?,
    publicKey: json['publicKey'] as String?,
    trustState: TrustState.values.firstWhere(
      (state) => state.name == json['trustState'],
      orElse: () => TrustState.unverified,
    ),
    lastSeen: DateTime.parse(json['lastSeen'] as String),
    connected: json['connected'] as bool? ?? false,
  );
}

enum TrustState { unverified, verified, keyChanged }

enum LiveVoiceState { calling, incoming, connected }

enum LiveVoiceQuality {
  good('dobra'),
  fair('średnia'),
  weak('słaba');

  const LiveVoiceQuality(this.label);

  final String label;
}

class LiveVoiceSession {
  const LiveVoiceSession({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.state,
    required this.initiatedByMe,
  });

  final String id;
  final String peerId;
  final String peerName;
  final LiveVoiceState state;
  final bool initiatedByMe;

  LiveVoiceSession copyWith({LiveVoiceState? state}) => LiveVoiceSession(
    id: id,
    peerId: peerId,
    peerName: peerName,
    state: state ?? this.state,
    initiatedByMe: initiatedByMe,
  );
}

class ChatGroup {
  const ChatGroup({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.createdAt,
  });

  final String id;
  final String name;
  final List<String> memberIds;
  final DateTime createdAt;

  static String threadIdFor(String id) => 'group:$id';

  String get threadId => threadIdFor(id);

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    return parts.isEmpty
        ? 'G'
        : parts
              .take(2)
              .map((part) => part.characters.first.toUpperCase())
              .join();
  }

  ChatGroup copyWith({String? name, List<String>? memberIds}) => ChatGroup(
    id: id,
    name: name ?? this.name,
    memberIds: memberIds ?? this.memberIds,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'memberIds': memberIds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChatGroup.fromJson(Map<String, dynamic> json) => ChatGroup(
    id: json['id'] as String,
    name: json['name'] as String,
    memberIds: (json['memberIds'] as List<dynamic>)
        .whereType<String>()
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class ChatThread {
  const ChatThread._({
    required this.id,
    required this.name,
    required this.initials,
    required this.isGroup,
    this.contact,
    this.group,
  });

  final String id;
  final String name;
  final String initials;
  final bool isGroup;
  final Contact? contact;
  final ChatGroup? group;

  factory ChatThread.contact(Contact contact) => ChatThread._(
    id: contact.threadId,
    name: contact.name,
    initials: contact.initials,
    isGroup: false,
    contact: contact,
  );

  factory ChatThread.group(ChatGroup group) => ChatThread._(
    id: group.threadId,
    name: group.name,
    initials: group.initials,
    isGroup: true,
    group: group,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.contactId,
    required this.text,
    required this.mine,
    required this.sentAt,
    this.status = MessageStatus.delivered,
    this.fileName,
    this.fileSize,
    this.filePath,
    this.fileTransferId,
    this.progress,
    this.senderName,
    this.attachmentType = MessageAttachmentType.file,
    this.voiceDurationMs,
  });

  final String id;
  final String contactId;
  final String text;
  final bool mine;
  final DateTime sentAt;
  final MessageStatus status;
  final String? fileName;
  final int? fileSize;
  final String? filePath;
  final String? fileTransferId;
  final double? progress;
  final String? senderName;
  final MessageAttachmentType attachmentType;
  final int? voiceDurationMs;

  bool get isVoiceMessage =>
      fileName != null && attachmentType == MessageAttachmentType.voice;

  ChatMessage copyWith({MessageStatus? status, double? progress}) =>
      ChatMessage(
        id: id,
        contactId: contactId,
        text: text,
        mine: mine,
        sentAt: sentAt,
        status: status ?? this.status,
        fileName: fileName,
        fileSize: fileSize,
        filePath: filePath,
        fileTransferId: fileTransferId,
        progress: progress ?? this.progress,
        senderName: senderName,
        attachmentType: attachmentType,
        voiceDurationMs: voiceDurationMs,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'contactId': contactId,
    'text': text,
    'mine': mine,
    'sentAt': sentAt.toIso8601String(),
    'status': status.name,
    'fileName': fileName,
    'fileSize': fileSize,
    'filePath': filePath,
    'fileTransferId': fileTransferId,
    'progress': progress,
    'senderName': senderName,
    'attachmentType': attachmentType.name,
    'voiceDurationMs': voiceDurationMs,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    contactId: json['contactId'] as String,
    text: json['text'] as String,
    mine: json['mine'] as bool,
    sentAt: DateTime.parse(json['sentAt'] as String),
    status: MessageStatus.values.firstWhere(
      (status) => status.name == json['status'],
      orElse: () => MessageStatus.delivered,
    ),
    fileName: json['fileName'] as String?,
    fileSize: json['fileSize'] as int?,
    filePath: json['filePath'] as String?,
    fileTransferId: json['fileTransferId'] as String?,
    progress: (json['progress'] as num?)?.toDouble(),
    senderName: json['senderName'] as String?,
    attachmentType: MessageAttachmentType.values.firstWhere(
      (type) => type.name == json['attachmentType'],
      orElse: () => MessageAttachmentType.file,
    ),
    voiceDurationMs: json['voiceDurationMs'] as int?,
  );
}

enum MessageAttachmentType { file, voice }

enum MessageStatus {
  sending('wysyłanie'),
  delivered('dostarczono'),
  failed('nie udało się');

  const MessageStatus(this.label);

  final String label;
}

class EncryptedText {
  const EncryptedText({
    required this.protocolVersion,
    required this.counter,
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final int protocolVersion;
  final int counter;
  final String nonce;
  final String cipherText;
  final String mac;
}

String _newId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

String _clock(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _safeFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_').trim();
  return cleaned.isEmpty ? 'plik' : cleaned;
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}
