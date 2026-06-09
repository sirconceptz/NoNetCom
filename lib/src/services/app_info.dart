part of '../../main.dart';

class AppAboutStatus {
  const AppAboutStatus({
    required this.appName,
    required this.version,
    required this.buildNumber,
    required this.notificationStatus,
    required this.notificationGood,
    required this.bluetoothPermissions,
    required this.errorLogBytes,
  });

  final String appName;
  final String version;
  final String buildNumber;
  final String notificationStatus;
  final bool notificationGood;
  final List<PermissionStatusItem> bluetoothPermissions;
  final int errorLogBytes;
}

class PermissionStatusItem {
  const PermissionStatusItem({
    required this.label,
    required this.status,
    required this.good,
  });

  final String label;
  final String status;
  final bool good;
}

class CapabilityStatusItem {
  const CapabilityStatusItem({
    required this.label,
    required this.status,
    required this.good,
    required this.fix,
    this.permission,
  });

  final String label;
  final String status;
  final bool good;
  final String fix;
  final Permission? permission;
}

class CapabilityService {
  List<Permission> essentialPermissions() {
    if (Platform.isAndroid) {
      return [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.locationWhenInUse,
        Permission.notification,
        Permission.microphone,
      ];
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return [
        Permission.bluetooth,
        Permission.notification,
        Permission.microphone,
      ];
    }
    return [Permission.notification, Permission.microphone];
  }

  Future<PermissionStatus> status(Permission permission) async {
    try {
      return permission.status;
    } on Object {
      return PermissionStatus.denied;
    }
  }

  bool isGood(PermissionStatus status) =>
      status.isGranted || status.isLimited || status.isProvisional;

  String label(PermissionStatus status) {
    if (status.isGranted) return 'przyznane';
    if (status.isLimited) return 'ograniczone';
    if (status.isProvisional) return 'tymczasowe';
    if (status.isPermanentlyDenied) return 'zablokowane';
    if (status.isRestricted) return 'ograniczone przez system';
    return 'brak zgody';
  }

  String permissionTitle(Permission permission) {
    if (permission == Permission.bluetoothScan) return 'Bluetooth: skanowanie';
    if (permission == Permission.bluetoothConnect) {
      return 'Bluetooth: połączenia';
    }
    if (permission == Permission.bluetoothAdvertise) {
      return 'Bluetooth: widoczność';
    }
    if (permission == Permission.bluetooth) return 'Bluetooth';
    if (permission == Permission.locationWhenInUse) {
      return 'Lokalizacja dla BLE';
    }
    if (permission == Permission.notification) return 'Powiadomienia';
    if (permission == Permission.microphone) return 'Mikrofon';
    return '$permission';
  }

  String fix(PermissionStatus status) {
    if (isGood(status)) return 'Gotowe.';
    if (status.isPermanentlyDenied) {
      return 'Odblokuj zgodę w ustawieniach systemowych.';
    }
    if (status.isRestricted) {
      return 'System ogranicza tę zgodę. Sprawdź ustawienia urządzenia.';
    }
    return 'Poproś ponownie o zgodę lub otwórz ustawienia systemowe.';
  }

  Future<List<CapabilityStatusItem>> loadStatus({
    required bool bluetoothRunning,
  }) async {
    final items = <CapabilityStatusItem>[];
    for (final permission in essentialPermissions()) {
      final current = await status(permission);
      items.add(
        CapabilityStatusItem(
          label: permissionTitle(permission),
          status: label(current),
          good: isGood(current),
          fix: fix(current),
          permission: permission,
        ),
      );
    }
    items.add(
      CapabilityStatusItem(
        label: 'Bluetooth LE',
        status: bluetoothRunning ? 'aktywny' : 'nieaktywny',
        good: bluetoothRunning,
        fix: bluetoothRunning
            ? 'Gotowe do parowania i odbioru.'
            : 'Uruchom Bluetooth w aplikacji i w systemie.',
      ),
    );
    items.add(
      const CapabilityStatusItem(
        label: 'Praca w tle',
        status: 'skonfigurowana',
        good: true,
        fix:
            'Android używa foreground service, iOS Core Bluetooth restoration.',
      ),
    );
    return items;
  }
}
