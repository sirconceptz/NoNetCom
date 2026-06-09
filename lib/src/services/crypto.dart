part of '../../main.dart';

class ChatCrypto {
  ChatCrypto({SimpleKeyPair? identity}) : _providedIdentity = identity;

  static const protocolVersion = 2;
  static const _privateKeyKey = 'identityPrivateKey';
  static const _publicKeyKey = 'identityPublicKey';
  static const _sendCountersKey = 'e2eeV2SendCounters';
  static const _seenCountersKey = 'e2eeV2SeenCounters';
  static const _replayWindowSize = 512;

  final SimpleKeyPair? _providedIdentity;
  final _algorithm = X25519();
  final _v2Cipher = AesGcm.with256bits();
  final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final Map<String, int> _sendCounters = {};
  final Map<String, Set<int>> _seenCounters = {};
  late SimpleKeyPair _identity;
  late Uint8List cachedPublicKey;
  late SharedPreferences _prefs;

  Future<void> loadOrCreate() async {
    _prefs = await SharedPreferences.getInstance();
    final providedIdentity = _providedIdentity;
    if (providedIdentity != null) {
      _identity = providedIdentity;
    } else {
      final savedPrivate = _prefs.getString(_privateKeyKey);
      final savedPublic = _prefs.getString(_publicKeyKey);
      if (savedPrivate != null && savedPublic != null) {
        _identity = SimpleKeyPairData(
          base64Decode(savedPrivate),
          publicKey: SimplePublicKey(
            base64Decode(savedPublic),
            type: KeyPairType.x25519,
          ),
          type: KeyPairType.x25519,
        );
      } else {
        _identity = await _algorithm.newKeyPair();
        await _persistIdentity();
      }
    }
    cachedPublicKey = Uint8List.fromList(
      (await _identity.extractPublicKey()).bytes,
    );
    _loadProtocolState();
  }

  Future<List<int>> publicKeyBytes() async =>
      (await _identity.extractPublicKey()).bytes;

  String get identityCode => fingerprintCode(base64Encode(cachedPublicKey));

  static String fingerprintCode(String publicKey) {
    final digest = Sha256().toSync().hashSync(base64Decode(publicKey)).bytes;
    final hex = digest
        .take(6)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return '${hex.substring(0, 4)} ${hex.substring(4, 8)} ${hex.substring(8, 12)}';
  }

  Future<String> exportIdentityBackup(String profileName) async {
    final privateBytes = await _identity.extractPrivateKeyBytes();
    final publicKey = await _identity.extractPublicKey();
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'NoNetCom',
      'createdAt': DateTime.now().toIso8601String(),
      'profileName': profileName,
      'warning':
          'Ten plik zawiera prywatna tozsamosc E2EE. Chron go jak haslo.',
      'privateKey': base64Encode(privateBytes),
      'publicKey': base64Encode(publicKey.bytes),
      'identityCode': identityCode,
    });
  }

  Future<String?> importIdentityBackup(String backupJson) async {
    final decoded = jsonDecode(backupJson);
    if (decoded is! Map<String, dynamic> || decoded['app'] != 'NoNetCom') {
      throw const FormatException('To nie jest backup NoNetCom');
    }
    final privateKey = decoded['privateKey'];
    final publicKey = decoded['publicKey'];
    if (privateKey is! String || publicKey is! String) {
      throw const FormatException('Backup nie zawiera kompletu kluczy');
    }
    final privateBytes = base64Decode(privateKey);
    final publicBytes = base64Decode(publicKey);
    _identity = SimpleKeyPairData(
      privateBytes,
      publicKey: SimplePublicKey(publicBytes, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );
    cachedPublicKey = Uint8List.fromList(publicBytes);
    _sendCounters.clear();
    _seenCounters.clear();
    await _persistIdentity();
    await _persistProtocolState();
    return decoded['profileName'] as String?;
  }

  Future<EncryptedText> encryptText({
    required String peerPublicKey,
    required String text,
    required String packetId,
  }) async {
    final peerFingerprint = _peerFingerprint(peerPublicKey);
    final counter = (_sendCounters[peerFingerprint] ?? 0) + 1;
    _sendCounters[peerFingerprint] = counter;
    await _persistSendCounters();
    final secretKey = await _directionalKey(
      peerPublicKey: peerPublicKey,
      senderPublicKey: base64Encode(cachedPublicKey),
      receiverPublicKey: peerPublicKey,
    );
    final nonce = _v2Cipher.newNonce();
    final secretBox = await _v2Cipher.encrypt(
      utf8.encode(text),
      secretKey: secretKey,
      nonce: nonce,
      aad: _aad(packetId, counter),
    );
    return EncryptedText(
      protocolVersion: protocolVersion,
      counter: counter,
      nonce: base64Encode(secretBox.nonce),
      cipherText: base64Encode(secretBox.cipherText),
      mac: base64Encode(secretBox.mac.bytes),
    );
  }

  Future<String> decryptText({
    required String peerPublicKey,
    required String packetId,
    required int protocolVersion,
    required int counter,
    required String nonce,
    required String cipherText,
    required String mac,
  }) async {
    if (protocolVersion != ChatCrypto.protocolVersion) {
      throw const FormatException('Nieobsługiwana wersja protokołu E2EE');
    }
    final secretKey = await _directionalKey(
      peerPublicKey: peerPublicKey,
      senderPublicKey: peerPublicKey,
      receiverPublicKey: base64Encode(cachedPublicKey),
    );
    final clear = await _v2Cipher.decrypt(
      SecretBox(
        base64Decode(cipherText),
        nonce: base64Decode(nonce),
        mac: Mac(base64Decode(mac)),
      ),
      secretKey: secretKey,
      aad: _aad(packetId, counter),
    );
    return utf8.decode(clear);
  }

  bool hasSeenCounter(String peerPublicKey, int counter) =>
      _seenCounters[_peerFingerprint(peerPublicKey)]?.contains(counter) ??
      false;

  Future<void> markCounterSeen(String peerPublicKey, int counter) async {
    final fingerprint = _peerFingerprint(peerPublicKey);
    final counters = _seenCounters.putIfAbsent(fingerprint, () => <int>{});
    counters.add(counter);
    if (counters.length > _replayWindowSize) {
      final sorted = counters.toList()..sort();
      counters.removeAll(sorted.take(counters.length - _replayWindowSize));
    }
    await _persistSeenCounters();
  }

  Future<SecretKey> _directionalKey({
    required String peerPublicKey,
    required String senderPublicKey,
    required String receiverPublicKey,
  }) async {
    final sharedSecret = await _sharedSecret(peerPublicKey);
    final participants = [senderPublicKey, receiverPublicKey]..sort();
    return _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: utf8.encode('NoNetCom E2EE v2'),
      info: utf8.encode(
        'participants=${participants.join(':')};'
        'sender=$senderPublicKey;receiver=$receiverPublicKey',
      ),
    );
  }

  List<int> _aad(String packetId, int counter) =>
      utf8.encode('NoNetCom|E2EE|v2|$packetId|$counter');

  String _peerFingerprint(String peerPublicKey) =>
      fingerprintCode(peerPublicKey).replaceAll(' ', '');

  Future<SecretKey> _sharedSecret(String peerPublicKey) {
    return _algorithm.sharedSecretKey(
      keyPair: _identity,
      remotePublicKey: SimplePublicKey(
        base64Decode(peerPublicKey),
        type: KeyPairType.x25519,
      ),
    );
  }

  Future<void> _persistIdentity() async {
    final privateBytes = await _identity.extractPrivateKeyBytes();
    final publicKey = await _identity.extractPublicKey();
    await _prefs.setString(_privateKeyKey, base64Encode(privateBytes));
    await _prefs.setString(_publicKeyKey, base64Encode(publicKey.bytes));
  }

  void _loadProtocolState() {
    final sendCounters =
        jsonDecode(_prefs.getString(_sendCountersKey) ?? '{}')
            as Map<String, dynamic>;
    _sendCounters
      ..clear()
      ..addAll(sendCounters.map((key, value) => MapEntry(key, value as int)));
    final seenCounters =
        jsonDecode(_prefs.getString(_seenCountersKey) ?? '{}')
            as Map<String, dynamic>;
    _seenCounters
      ..clear()
      ..addAll(
        seenCounters.map(
          (key, value) =>
              MapEntry(key, (value as List<dynamic>).whereType<int>().toSet()),
        ),
      );
  }

  Future<void> _persistProtocolState() async {
    await _persistSendCounters();
    await _persistSeenCounters();
  }

  Future<void> _persistSendCounters() =>
      _prefs.setString(_sendCountersKey, jsonEncode(_sendCounters));

  Future<void> _persistSeenCounters() => _prefs.setString(
    _seenCountersKey,
    jsonEncode(
      _seenCounters.map(
        (key, value) => MapEntry(key, (value.toList()..sort())),
      ),
    ),
  );
}
