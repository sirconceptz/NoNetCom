// ignore_for_file: invalid_use_of_protected_member

part of '../../../main.dart';

extension _LifecycleController on _ChatShellState {
  Future<void> _handleLifecycleState(AppLifecycleState state) async {
    await _recordDiagnostic('app_lifecycle', state.name);
    if (state == AppLifecycleState.resumed) {
      if (!_bluetoothRunning && !_locked && !_showOnboarding) {
        await _startBluetooth();
      }
      await _flushQueuedMessages();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      setState(() => _status = 'NoNetCom działa w tle');
    }
  }

  Future<void> _boot() async {
    await _store.load();
    await _transport.load();
    _transport.discardWhere(
      (envelope) =>
          envelope.packetId.startsWith('live-control:') ||
          envelope.packetId.startsWith('live-audio:') ||
          envelope.packetId.startsWith('live-end:'),
    );
    _outboundFiles.addAll(_store.pendingOutboundFiles);
    _groupDeliveries.addAll(_store.pendingGroupDeliveries);
    await _security.load();
    await _diagnostics.load();
    await _notifications.load();
    await _crypto.loadOrCreate();
    if (!mounted || _disposed) return;
    await _recordDiagnostic('app_boot', 'Aplikacja uruchomiona');
    _nameController.text = _store.profileName;
    _locked = _security.pinEnabled;
    _bleSubscription = _ble.events.listen(_handleBleEvent);
    _retryTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _flushQueuedMessages(),
    );
    setState(() {
      _ready = true;
      _showOnboarding = !_store.onboardingSeen && !_locked;
      _status = _locked ? 'Aplikacja zablokowana' : 'Gotowe do pracy offline';
    });
    if (_locked || _showOnboarding) {
      return;
    }
    await _startBluetooth();
    if (!mounted || _disposed) return;
    await _flushQueuedMessages();
    await _showOnboardingIfNeeded();
  }

  Future<void> _finishOnboarding() async {
    await _store.markOnboardingSeen();
    await _recordDiagnostic('onboarding_done', 'Ukończono onboarding');
    setState(() {
      _showOnboarding = false;
      _status = 'Gotowe do pracy offline';
    });
    if (!_bluetoothRunning) {
      await _startBluetooth();
    }
  }

  Future<void> _skipOnboarding() async {
    await _store.markOnboardingSeen();
    await _recordDiagnostic('onboarding_skipped', 'Pominięto onboarding');
    if (!mounted) return;
    setState(() {
      _showOnboarding = false;
      _status = 'Konfigurację możesz dokończyć w ustawieniach';
    });
  }

  Future<void> _showOnboardingIfNeeded() async {
    if (_store.onboardingSeen || _disposed || !mounted) return;
    setState(() => _showOnboarding = true);
  }

  Future<void> _startBluetooth() async {
    setState(() => _status = 'Uruchamiam komunikację z osobami w pobliżu...');
    try {
      await _ble.start(
        displayName: _store.profileName,
        publicKey: base64Encode(await _crypto.publicKeyBytes()),
      );
      await _recordDiagnostic('ble_start', 'Bluetooth LE uruchomiony');
      setState(() {
        _bluetoothRunning = true;
        _status = 'Jesteś widoczny dla osób w pobliżu';
      });
      _showFeedback('Gotowe. Inne osoby mogą Cię teraz znaleźć.');
    } on PlatformException catch (error) {
      await _recordDiagnostic(
        'ble_error',
        error.message ?? error.code,
        level: DiagnosticLevel.warning,
      );
      setState(() {
        _bluetoothRunning = false;
        _status =
            'Nie udało się włączyć komunikacji. Sprawdź Bluetooth i zgody.';
      });
      _showFeedback(
        'Nie udało się włączyć połączeń. Sprawdź zgody i spróbuj ponownie.',
      );
    }
  }

  Future<void> _scan() async {
    if (!_bluetoothRunning) {
      await _startBluetooth();
    }
    setState(() {
      _scanning = true;
      _status = 'Szukam kontaktów w pobliżu...';
    });
    await _recordDiagnostic('scan_start', 'Rozpoczęto skanowanie BLE');
    _showFeedback('Szukam osób w pobliżu. Zostaw telefony blisko siebie.');
    await _ble.scan();
    await Future<void>.delayed(const Duration(seconds: 8));
    if (mounted) {
      await _recordDiagnostic('scan_stop', 'Zakończono skanowanie BLE');
      setState(() {
        _scanning = false;
        _status = 'Skończyłem szukać osób w pobliżu';
      });
      _showFeedback(
        'Szukanie zakończone. Jeśli nikogo nie ma, sprawdź Bluetooth na obu telefonach.',
      );
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    await _store.setProfileName(name);
    if (!_showOnboarding) {
      await _startBluetooth();
    }
    await _recordDiagnostic('profile_renamed', 'Zmieniono nazwę profilu');
    setState(() => _status = 'Nazwa profilu zapisana');
    _showFeedback('Nazwa zapisana. Tak zobaczą Cię osoby w pobliżu.');
  }

  Future<void> _editProfileName() async {
    final controller = TextEditingController(text: _store.profileName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Twoja nazwa'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nazwa widoczna dla osób w pobliżu',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == _store.profileName) return;
    _nameController.text = name;
    await _saveName();
  }
}
