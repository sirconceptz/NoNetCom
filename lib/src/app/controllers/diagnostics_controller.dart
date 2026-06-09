// ignore_for_file: invalid_use_of_protected_member

part of '../../../main.dart';

extension _DiagnosticsController on _ChatShellState {
  Future<void> _exportDiagnosticsReport() async {
    final file = await _diagnosticsReport.export(_diagnosticsSnapshot);
    await _recordDiagnostic('diagnostics_exported', 'Zapisano raport');
    setState(() => _status = 'Raport zapisany: ${file.path}');
  }

  Future<void> _openDiagnostics() async {
    final permissions = await _loadCapabilityStatus();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diagnostyka'),
        content: SizedBox(
          width: 680,
          child: ListView(
            shrinkWrap: true,
            children: [
              _StatusTile(
                icon: _bluetoothRunning
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                title: 'Bluetooth LE',
                value: _bluetoothRunning ? 'aktywny' : 'nieaktywny',
                good: _bluetoothRunning,
              ),
              _StatusTile(
                icon: Icons.radar,
                title: 'Skanowanie',
                value: _scanning ? 'trwa' : 'nieaktywne',
                good: !_scanning,
              ),
              _StatusTile(
                icon: Icons.people_outline,
                title: 'Kontakty online',
                value:
                    '${_store.contacts.where((c) => c.connected).length}/${_store.contacts.length}',
                good: _store.contacts.any((contact) => contact.connected),
              ),
              _StatusTile(
                icon: Icons.queue_outlined,
                title: 'Kolejka pakietów',
                value: '${_transport.pendingCount}',
                good: _transport.pendingCount == 0,
              ),
              _StatusTile(
                icon: Icons.file_upload_outlined,
                title: 'Transfery plików',
                value:
                    '${_outboundFiles.length} wychodzące, ${_inboundFiles.length} przychodzące',
                good: _outboundFiles.isEmpty && _inboundFiles.isEmpty,
              ),
              const Divider(),
              Text(
                'Uprawnienia i naprawa',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final item in permissions)
                _CapabilityStatusRow(
                  item: item,
                  onRequest: item.permission == null
                      ? null
                      : () => _requestPermissionFromDialog(
                          context,
                          item.permission!,
                        ),
                  onSettings: openAppSettings,
                ),
              const Divider(),
              Text('Status: $_status'),
              Text('Zdarzenia diagnostyczne: ${_diagnostics.entries.length}'),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _requestEssentialPermissions,
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('Poproś o zgody'),
          ),
          TextButton.icon(
            onPressed: _startBluetooth,
            icon: const Icon(Icons.bluetooth_connected),
            label: const Text('Uruchom Bluetooth'),
          ),
          TextButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.radar),
            label: const Text('Skanuj'),
          ),
          TextButton(
            onPressed: _exportDiagnosticsReport,
            child: const Text('Eksportuj raport'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermissionFromDialog(
    BuildContext dialogContext,
    Permission permission,
  ) async {
    await _requestPermission(permission);
    if (dialogContext.mounted) Navigator.pop(dialogContext);
    await _openDiagnostics();
  }

  Future<void> _requestEssentialPermissions() async {
    for (final permission in _essentialPermissions()) {
      await _requestPermission(permission);
    }
    await _recordDiagnostic(
      'permissions_requested',
      'Poproszono o wymagane uprawnienia',
    );
    if (!mounted) return;
    setState(() => _status = 'Sprawdzono uprawnienia systemowe');
  }

  Future<void> _requestPermission(Permission permission) async {
    final status = await _safePermissionStatus(permission);
    if (status.isPermanentlyDenied || status.isRestricted) {
      await openAppSettings();
      return;
    }
    try {
      await permission.request();
    } on Object catch (error, stack) {
      await AppErrorLog.instance.logError(
        error,
        stack,
        source: 'permission_request',
      );
      await _recordDiagnostic(
        'permission_error',
        '$permission',
        level: DiagnosticLevel.warning,
      );
    }
  }

  List<Permission> _essentialPermissions() {
    return _capabilities.essentialPermissions();
  }

  Future<List<CapabilityStatusItem>> _loadCapabilityStatus() async {
    return _capabilities.loadStatus(bluetoothRunning: _bluetoothRunning);
  }

  Future<void> _openAboutApp() async {
    final info = await _loadAboutStatus();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('O aplikacji'),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.offline_bolt)),
                title: Text(info.appName),
                subtitle: Text('Wersja ${info.version}+${info.buildNumber}'),
              ),
              const Divider(),
              _StatusTile(
                icon: Icons.bluetooth_connected,
                title: 'Bluetooth',
                value: _bluetoothRunning ? 'aktywny' : 'nieaktywny',
                good: _bluetoothRunning,
              ),
              _StatusTile(
                icon: Icons.radar,
                title: 'Skanowanie',
                value: _scanning ? 'trwa' : 'nieaktywne',
                good: !_scanning,
              ),
              _StatusTile(
                icon: Icons.people_outline,
                title: 'Kontakty online',
                value:
                    '${_store.contacts.where((c) => c.connected).length}/${_store.contacts.length}',
                good: _store.contacts.any((contact) => contact.connected),
              ),
              _StatusTile(
                icon: Icons.notifications_outlined,
                title: 'Powiadomienia',
                value: info.notificationStatus,
                good: info.notificationGood,
              ),
              for (final item in info.bluetoothPermissions)
                _StatusTile(
                  icon: Icons.settings_bluetooth,
                  title: item.label,
                  value: item.status,
                  good: item.good,
                ),
              _StatusTile(
                icon: Icons.queue_outlined,
                title: 'Kolejka pakietów',
                value: '${_transport.pendingCount}',
                good: _transport.pendingCount == 0,
              ),
              _StatusTile(
                icon: Icons.bug_report_outlined,
                title: 'Logi błędów',
                value: _formatBytes(info.errorLogBytes),
                good: info.errorLogBytes == 0,
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _exportDiagnosticsReport,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Eksportuj diagnostykę'),
          ),
          TextButton.icon(
            onPressed: _openErrorLogs,
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('Logi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }

  Future<AppAboutStatus> _loadAboutStatus() async {
    final package = await PackageInfo.fromPlatform();
    final notification = await _safePermissionStatus(Permission.notification);
    final bluetoothPermissions = <PermissionStatusItem>[];
    if (Platform.isAndroid) {
      bluetoothPermissions.addAll([
        PermissionStatusItem(
          label: 'Bluetooth: skanowanie',
          status: _permissionLabel(
            await _safePermissionStatus(Permission.bluetoothScan),
          ),
          good: await _permissionGood(Permission.bluetoothScan),
        ),
        PermissionStatusItem(
          label: 'Bluetooth: połączenia',
          status: _permissionLabel(
            await _safePermissionStatus(Permission.bluetoothConnect),
          ),
          good: await _permissionGood(Permission.bluetoothConnect),
        ),
        PermissionStatusItem(
          label: 'Bluetooth: reklamowanie',
          status: _permissionLabel(
            await _safePermissionStatus(Permission.bluetoothAdvertise),
          ),
          good: await _permissionGood(Permission.bluetoothAdvertise),
        ),
      ]);
    } else if (Platform.isIOS || Platform.isMacOS) {
      final bluetooth = await _safePermissionStatus(Permission.bluetooth);
      bluetoothPermissions.add(
        PermissionStatusItem(
          label: 'Bluetooth',
          status: _permissionLabel(bluetooth),
          good: _permissionStatusGood(bluetooth),
        ),
      );
    }
    return AppAboutStatus(
      appName: package.appName,
      version: package.version,
      buildNumber: package.buildNumber,
      notificationStatus: _permissionLabel(notification),
      notificationGood: _permissionStatusGood(notification),
      bluetoothPermissions: bluetoothPermissions,
      errorLogBytes: await AppErrorLog.instance.totalBytes(),
    );
  }

  Future<PermissionStatus> _safePermissionStatus(Permission permission) async {
    return _capabilities.status(permission);
  }

  Future<bool> _permissionGood(Permission permission) async =>
      _permissionStatusGood(await _safePermissionStatus(permission));

  bool _permissionStatusGood(PermissionStatus status) =>
      _capabilities.isGood(status);

  String _permissionLabel(PermissionStatus status) {
    return _capabilities.label(status);
  }

  Future<void> _openDataCenter() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dane lokalne'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Wiadomości: ${_store.messages.length}'),
            Text('Kontakty: ${_store.contacts.length}'),
            Text('Zdarzenia diagnostyczne: ${_diagnostics.entries.length}'),
            FutureBuilder<int>(
              future: AppErrorLog.instance.totalBytes(),
              builder: (context, snapshot) =>
                  Text('Logi błędów: ${_formatBytes(snapshot.data ?? 0)}'),
            ),
            const SizedBox(height: 12),
            Text(
              'Logi błędów zawierają informacje techniczne o awariach aplikacji. Nie zapisujemy w nich treści rozmów ani zawartości plików.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _store.includeDiagnosticsInErrorReport,
              onChanged: (value) async {
                await _store.setIncludeDiagnosticsInErrorReport(value);
                setState(() {});
              },
              title: const Text('Dołącz metadane diagnostyczne do maila'),
              subtitle: const Text(
                'Dodaje status Bluetooth, liczbę kontaktów, kolejkę pakietów i zdarzenia techniczne.',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Backup kontaktów eksportuje wyłącznie zaufane kontakty z publicznymi kluczami. Nie zapisuje prywatnego klucza E2EE ani treści rozmów.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _AppSectionAction(
              onPressed: _exportTrustedContacts,
              icon: Icons.ios_share,
              label: 'Eksportuj zaufane kontakty',
            ),
            const SizedBox(height: 8),
            _AppSectionAction(
              onPressed: () => _importTrustedContactsFromDialog(context),
              icon: Icons.restore_page_outlined,
              label: 'Importuj kontakty po reinstallu',
            ),
            const SizedBox(height: 12),
            _AppSectionAction(
              onPressed: _exportDiagnosticsReport,
              icon: Icons.description_outlined,
              label: 'Eksportuj raport diagnostyczny',
            ),
            const SizedBox(height: 8),
            _AppSectionAction(
              onPressed: _openErrorLogs,
              icon: Icons.bug_report_outlined,
              label: 'Pokaż logi błędów',
            ),
            const SizedBox(height: 8),
            _AppSectionAction(
              onPressed: _sendErrorLogsToDeveloper,
              icon: Icons.outgoing_mail,
              label: 'Wyślij logi do dewelopera',
            ),
            const SizedBox(height: 8),
            _AppSectionAction(
              onPressed: () => _clearErrorLogsFromDialog(context),
              icon: Icons.delete_outline,
              label: 'Wyczyść logi błędów',
            ),
            const SizedBox(height: 8),
            _AppSectionAction(
              onPressed: () => _clearDiagnosticsFromDialog(context),
              icon: Icons.cleaning_services_outlined,
              label: 'Wyczyść diagnostykę',
            ),
            const SizedBox(height: 8),
            _AppSectionAction(
              onPressed: () => _clearMessagesFromDialog(context),
              icon: Icons.delete_sweep_outlined,
              label: 'Wyczyść historię rozmów',
            ),
            const SizedBox(height: 8),
            _AppSectionAction(
              onPressed: () => _clearContactsFromDialog(context),
              icon: Icons.person_remove_outlined,
              label: 'Usuń kontakty',
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

  Future<void> _exportTrustedContacts() async {
    final backup = _store.exportTrustedContactsBackup();
    final directory = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${directory.path}/NoNetCom');
    if (!backupDir.existsSync()) backupDir.createSync(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File(
      '${backupDir.path}/nonetcom-trusted-contacts-$stamp.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(backup),
    );
    await _recordDiagnostic(
      'trusted_contacts_exported',
      'Wyeksportowano ${backup['contactsCount']} zaufanych kontaktów',
    );
    setState(
      () => _status = 'Zapisano backup zaufanych kontaktów: ${file.path}',
    );
  }

  Future<void> _importTrustedContactsFromDialog(
    BuildContext dialogContext,
  ) async {
    final confirmed = await _confirmDestructive(
      title: 'Importować zaufane kontakty?',
      body:
          'Import doda lub zaktualizuje lokalne nazwy, publiczne klucze i status zaufania kontaktów. Nie zmieni prywatnej tożsamości E2EE tej instalacji.',
    );
    if (confirmed != true) return;
    final file = await FileChooserBridge.pickFile();
    if (file == null) return;
    if (file.size > 1024 * 1024) {
      setState(() => _status = 'Backup kontaktów jest zbyt duży');
      return;
    }
    try {
      final raw = await File(file.path).readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Nieprawidłowy format backupu kontaktów');
      }
      final imported = await _store.importTrustedContactsBackup(decoded);
      await _recordDiagnostic(
        'trusted_contacts_imported',
        'Zaimportowano $imported zaufanych kontaktów',
      );
      setState(() {
        _status = imported == 0
            ? 'Backup nie zawierał nowych zaufanych kontaktów'
            : 'Zaimportowano zaufane kontakty: $imported';
      });
      if (dialogContext.mounted) Navigator.pop(dialogContext);
    } on FormatException catch (error) {
      await _recordDiagnostic(
        'trusted_contacts_import_failed',
        error.message,
        level: DiagnosticLevel.warning,
      );
      setState(() => _status = 'Nieprawidłowy backup kontaktów');
    } on FileSystemException catch (error) {
      await _recordDiagnostic(
        'trusted_contacts_import_failed',
        error.message,
        level: DiagnosticLevel.warning,
      );
      setState(() => _status = 'Nie udało się odczytać backupu kontaktów');
    }
  }

  Future<void> _openErrorLogs() async {
    final logs = await AppErrorLog.instance.readAll();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logi błędów'),
        content: SizedBox(
          width: 720,
          height: 420,
          child: logs.isEmpty
              ? const Center(child: Text('Brak zapisanych błędów.'))
              : Scrollbar(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      logs,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton.icon(
            onPressed: logs.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: logs));
                    if (context.mounted) Navigator.pop(context);
                    setState(() => _status = 'Skopiowano logi błędów');
                  },
            icon: const Icon(Icons.copy),
            label: const Text('Kopiuj całość'),
          ),
          TextButton.icon(
            onPressed: _sendErrorLogsToDeveloper,
            icon: const Icon(Icons.outgoing_mail),
            label: const Text('Wyślij'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendErrorLogsToDeveloper() async {
    try {
      final diagnostics = _store.includeDiagnosticsInErrorReport
          ? _diagnosticsAsLogSection()
          : null;
      final file = await AppErrorLog.instance.exportCombinedFile(
        appendix: diagnostics,
      );
      final size = await file.length();
      if (size == 0) {
        setState(() => _status = 'Brak logów błędów do wysłania');
        return;
      }
      await FlutterEmailSender.send(
        Email(
          recipients: const [_developerLogEmail],
          subject: 'NoNetCom logi błędów ${AppErrorLog.instance.version}',
          body: _store.includeDiagnosticsInErrorReport
              ? 'W załączniku są lokalne logi błędów NoNetCom oraz metadane diagnostyczne. Nie powinny zawierać treści rozmów ani plików użytkownika.'
              : 'W załączniku są lokalne logi błędów NoNetCom. Nie powinny zawierać treści rozmów ani plików użytkownika.',
          attachmentPaths: [file.path],
        ),
      );
      await _recordDiagnostic(
        'error_logs_shared',
        'Przygotowano wysyłkę logów',
      );
      setState(() => _status = 'Otworzono wysyłkę logów do dewelopera');
    } on PlatformException catch (error) {
      await AppErrorLog.instance.logError(
        error,
        StackTrace.current,
        source: 'send_error_logs',
      );
      setState(() => _status = 'Nie udało się otworzyć aplikacji mailowej');
    } on FileSystemException catch (error) {
      await AppErrorLog.instance.logError(
        error,
        StackTrace.current,
        source: 'send_error_logs',
      );
      setState(() => _status = 'Nie udało się przygotować pliku logów');
    }
  }

  String _diagnosticsAsLogSection() {
    return _diagnosticsReport.asLogSection(_diagnosticsSnapshot);
  }

  DiagnosticsSnapshot get _diagnosticsSnapshot => DiagnosticsSnapshot(
    bluetoothRunning: _bluetoothRunning,
    scanning: _scanning,
    contactsCount: _store.contacts.length,
    connectedContactsCount: _store.contacts
        .where((contact) => contact.connected)
        .length,
    messagesCount: _store.messages.length,
    pendingPackets: _transport.pendingCount,
    outboundTransfers: _outboundFiles.length,
    inboundTransfers: _inboundFiles.length,
    status: _status,
    events: List.unmodifiable(_diagnostics.entries),
  );

  Future<void> _clearErrorLogsFromDialog(BuildContext dialogContext) async {
    final confirmed = await _confirmDestructive(
      title: 'Wyczyścić logi błędów?',
      body:
          'Usunie to lokalne pliki logów błędów dla aktualnej wersji aplikacji.',
    );
    if (confirmed != true) return;
    await AppErrorLog.instance.clearCurrentVersion();
    await _recordDiagnostic('error_logs_cleared', 'Wyczyszczono logi błędów');
    setState(() => _status = 'Logi błędów wyczyszczone');
    if (dialogContext.mounted) Navigator.pop(dialogContext);
  }

  Future<void> _clearDiagnosticsFromDialog(BuildContext dialogContext) async {
    await _diagnostics.clear();
    await _recordDiagnostic('diagnostics_cleared', 'Wyczyszczono diagnostykę');
    setState(() => _status = 'Diagnostyka wyczyszczona');
    if (dialogContext.mounted) Navigator.pop(dialogContext);
  }

  Future<void> _clearMessagesFromDialog(BuildContext dialogContext) async {
    final confirmed = await _confirmDestructive(
      title: 'Wyczyścić historię rozmów?',
      body:
          'Usunie to lokalne wiadomości i wpisy plików z aplikacji. Odebrane pliki w katalogu aplikacji pozostaną na dysku.',
    );
    if (confirmed != true) return;
    await _store.clearMessages();
    _outboundFiles.clear();
    _groupDeliveries.clear();
    await _transport.clear();
    await _recordDiagnostic('messages_cleared', 'Wyczyszczono historię rozmów');
    setState(() => _status = 'Historia rozmów wyczyszczona');
    if (dialogContext.mounted) Navigator.pop(dialogContext);
  }

  Future<void> _clearContactsFromDialog(BuildContext dialogContext) async {
    final confirmed = await _confirmDestructive(
      title: 'Usunąć kontakty?',
      body:
          'Usunie to lokalne nazwy, klucze i status zaufania kontaktów. Do ponownej rozmowy potrzebne będzie skanowanie i weryfikacja kluczy.',
    );
    if (confirmed != true) return;
    await _store.clearContacts();
    _selectedThreadId = null;
    await _recordDiagnostic('contacts_cleared', 'Usunięto kontakty');
    setState(() => _status = 'Kontakty usunięte');
    if (dialogContext.mounted) Navigator.pop(dialogContext);
  }

  Future<bool?> _confirmDestructive({
    required String title,
    required String body,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Potwierdź'),
          ),
        ],
      ),
    );
  }

  Future<void> _recordDiagnostic(
    String type,
    String message, {
    DiagnosticLevel level = DiagnosticLevel.info,
  }) {
    if (level == DiagnosticLevel.error) {
      unawaited(AppErrorLog.instance.logInfo('diagnostic:$type:$message'));
    }
    return _diagnostics.add(
      DiagnosticEntry(
        type: type,
        message: message,
        level: level,
        createdAt: DateTime.now(),
      ),
    );
  }
}
