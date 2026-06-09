part of '../../main.dart';

class AppSecurity {
  static const _pinDigestKey = 'appLockPinDigest';

  final _localAuth = LocalAuthentication();
  late SharedPreferences _prefs;
  String? _pinDigest;

  bool get pinEnabled => _pinDigest != null;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _pinDigest = _prefs.getString(_pinDigestKey);
  }

  Future<void> setPin(String pin) async {
    _pinDigest = await _digest(pin);
    await _prefs.setString(_pinDigestKey, _pinDigest!);
  }

  Future<void> clearPin() async {
    _pinDigest = null;
    await _prefs.remove(_pinDigestKey);
  }

  Future<bool> verifyPin(String pin) async {
    final digest = _pinDigest;
    return digest != null && digest == await _digest(pin);
  }

  Future<bool> tryBiometric() async {
    if (!pinEnabled) return false;
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported && !canCheck) return false;
      return _localAuth.authenticate(
        localizedReason: 'Odblokuj NoNetCom',
        biometricOnly: false,
      );
    } on PlatformException {
      return false;
    }
  }

  Future<String> _digest(String pin) async {
    final hash = await Sha256().hash(utf8.encode('skybridge:$pin'));
    return base64Encode(hash.bytes);
  }
}
