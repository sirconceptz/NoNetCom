// ignore_for_file: invalid_use_of_protected_member

part of '../../../main.dart';

extension _SecurityController on _ChatShellState {
  Future<void> _unlock() async {
    if (await _security.tryBiometric()) {
      await _finishUnlock();
      return;
    }
    if (!mounted) return;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Odblokuj NoNetCom'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'PIN'),
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              final valid = await _security.verifyPin(controller.text);
              if (context.mounted) Navigator.pop(context, valid);
            },
            child: const Text('Odblokuj'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (ok == true) {
      await _finishUnlock();
    } else {
      setState(() => _status = 'Nieprawidłowy PIN');
    }
  }

  Future<void> _finishUnlock() async {
    setState(() {
      _locked = false;
      _status = 'Odblokowano';
    });
    await _startBluetooth();
    await _flushQueuedMessages();
    await _showOnboardingIfNeeded();
  }

  Future<void> _openSecurityCenter() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bezpieczeństwo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Twoja tożsamość: ${_crypto.identityCode}'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _setPinFromDialog(context),
              icon: const Icon(Icons.pin),
              label: Text(_security.pinEnabled ? 'Zmień PIN' : 'Ustaw PIN'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _security.pinEnabled
                  ? () => _clearPinFromDialog(context)
                  : null,
              icon: const Icon(Icons.lock_open),
              label: const Text('Wyłącz blokadę PIN'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _exportIdentityBackup,
              icon: const Icon(Icons.ios_share),
              label: const Text('Eksportuj backup tożsamości'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _importIdentityBackup,
              icon: const Icon(Icons.restore_page_outlined),
              label: const Text('Importuj backup tożsamości'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _showEncryptionInfo,
              icon: const Icon(Icons.info_outline),
              label: const Text('Co jest szyfrowane'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }

  Future<void> _setPinFromDialog(BuildContext dialogContext) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ustaw PIN'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minimum 4 cyfry'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (pin == null || pin.length < 4) return;
    await _security.setPin(pin);
    setState(() => _status = 'PIN zapisany');
    if (dialogContext.mounted) Navigator.pop(dialogContext);
  }

  Future<void> _clearPinFromDialog(BuildContext dialogContext) async {
    await _security.clearPin();
    setState(() => _status = 'Blokada PIN wyłączona');
    if (dialogContext.mounted) Navigator.pop(dialogContext);
  }

  Future<void> _exportIdentityBackup() async {
    final directory = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${directory.path}/NoNetCom');
    if (!backupDir.existsSync()) backupDir.createSync(recursive: true);
    final file = File('${backupDir.path}/nonetcom-identity-backup.json');
    await file.writeAsString(
      await _crypto.exportIdentityBackup(_store.profileName),
    );
    await _recordDiagnostic('identity_backup_exported', 'Zapisano backup');
    setState(() => _status = 'Backup zapisany: ${file.path}');
  }

  Future<void> _importIdentityBackup() async {
    final confirmed = await _confirmDestructive(
      title: 'Importować tożsamość E2EE?',
      body:
          'Zastąpi to lokalny klucz prywatny tej instalacji. Kontakty mogą wymagać ponownej weryfikacji kodu bezpieczeństwa.',
    );
    if (confirmed != true) return;
    final file = await FileChooserBridge.pickFile();
    if (file == null) return;
    if (file.size > 1024 * 1024) {
      setState(() => _status = 'Backup jest zbyt duży');
      return;
    }
    try {
      final backup = await File(file.path).readAsString();
      final profileName = await _crypto.importIdentityBackup(backup);
      if (profileName != null && profileName.trim().isNotEmpty) {
        await _store.setProfileName(profileName.trim());
        _nameController.text = _store.profileName;
      }
      await _recordDiagnostic(
        'identity_backup_imported',
        'Zaimportowano backup tożsamości',
      );
      await _startBluetooth();
      setState(() => _status = 'Tożsamość E2EE zaimportowana');
    } on FormatException catch (error) {
      await _recordDiagnostic(
        'identity_backup_import_failed',
        error.message,
        level: DiagnosticLevel.warning,
      );
      setState(() => _status = 'Nieprawidłowy plik backupu');
    } on FileSystemException catch (error) {
      await _recordDiagnostic(
        'identity_backup_import_failed',
        error.message,
        level: DiagnosticLevel.warning,
      );
      setState(() => _status = 'Nie udało się odczytać backupu');
    }
  }

  Future<void> _showEncryptionInfo() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Szyfrowanie'),
        content: const Text(
          'Treść wiadomości i chunki plików są szyfrowane end-to-end przez X25519 oraz AES-GCM. Metadane transportowe BLE, takie jak identyfikatory ramek i postęp transferu, nie są treścią wiadomości.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
