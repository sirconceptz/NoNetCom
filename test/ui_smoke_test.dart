import 'dart:async';
import 'dart:convert';

import 'package:ble_communicator/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

void main() {
  testWidgets('starts on onboarding and can skip it', (tester) async {
    final dependencies = await _prepareDependencies(
      prefix: 'nonetcom-ui-onboarding-',
      onboardingSeen: false,
    );

    await tester.pumpWidget(_testApp(dependencies));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Rozmawiaj bez internetu'), findsOneWidget);
    expect(find.text('Pomiń'), findsOneWidget);

    await tester.tap(find.text('Pomiń'));
    await _pumpUi(tester);

    expect(find.text('Szukaj rozmów'), findsOneWidget);
    expect(find.text('Najpierw włącz połączenia'), findsOneWidget);

    await _disposeApp(tester);
  });

  testWidgets('opens advanced settings from the main menu', (tester) async {
    final dependencies = await _prepareDependencies(
      prefix: 'nonetcom-ui-advanced-',
      onboardingSeen: true,
    );

    await tester.pumpWidget(_testApp(dependencies));
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Menu aplikacji'));
    await _pumpUi(tester);
    await tester.tap(find.text('Ustawienia'));
    await _pumpUi(tester);
    await tester.tap(find.text('Zaawansowane'));
    await _pumpUi(tester);

    expect(find.text('Diagnostyka połączenia'), findsOneWidget);
    expect(find.text('Dane lokalne i logi'), findsOneWidget);
    expect(find.text('Informacje techniczne'), findsOneWidget);

    await _disposeApp(tester);
  });

  testWidgets('opens a conversation from the conversation list', (
    tester,
  ) async {
    final contact = _trustedContact();
    final message = ChatMessage(
      id: 'message-1',
      contactId: contact.threadId,
      text: 'Cześć z offline',
      mine: false,
      sentAt: DateTime(2026, 6, 19, 12),
    );
    final dependencies = await _prepareDependencies(
      prefix: 'nonetcom-ui-chat-',
      onboardingSeen: true,
      contacts: [contact],
      messages: [message],
    );

    await tester.pumpWidget(_testApp(dependencies));
    await _pumpUi(tester);

    await tester.tap(find.text(contact.name));
    await _pumpUi(tester);

    expect(find.text(contact.name), findsWidgets);
    expect(find.text('Cześć z offline'), findsOneWidget);
    expect(find.byTooltip('Wyślij'), findsOneWidget);

    await _disposeApp(tester);
  });

  testWidgets('opens contact verification dialog from chat', (tester) async {
    final contact = _trustedContact(trustState: TrustState.unverified);
    final dependencies = await _prepareDependencies(
      prefix: 'nonetcom-ui-verify-',
      onboardingSeen: true,
      contacts: [contact],
    );

    await tester.pumpWidget(_testApp(dependencies));
    await _pumpUi(tester);

    await tester.tap(find.text(contact.name));
    await _pumpUi(tester);
    await tester.tap(find.byTooltip('Więcej opcji'));
    await _pumpUi(tester);
    await tester.tap(find.text('Zweryfikuj kontakt'));
    await _pumpUi(tester);

    expect(find.text('Zweryfikuj: ${contact.name}'), findsOneWidget);
    expect(find.text('Co teraz?'), findsOneWidget);
    expect(find.text('Pokaż mój kod'), findsOneWidget);
    expect(find.text('Skanuj kod kontaktu'), findsOneWidget);

    await _disposeApp(tester);
  });
}

Widget _testApp(AppDependencies dependencies) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: ChatShell(dependencies: dependencies),
);

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<AppDependencies> _prepareDependencies({
  required String prefix,
  required bool onboardingSeen,
  List<Contact> contacts = const [],
  List<ChatMessage> messages = const [],
}) async {
  await prepareTestAppStorage(prefix);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboardingSeen', onboardingSeen);
  await prefs.setString('profileName', 'Tester');
  await prefs.setStringList(
    'contacts',
    contacts.map((contact) => jsonEncode(contact.toJson())).toList(),
  );
  await prefs.setStringList(
    'messages',
    messages.map((message) => jsonEncode(message.toJson())).toList(),
  );

  return AppDependencies(
    store: ChatStore(),
    crypto: ChatCrypto(),
    ble: _FakeBleBridge(),
    security: AppSecurity(),
    diagnostics: DiagnosticLog(),
    notifications: _FakeNotifications(),
    voice: _FakeVoiceMessagingService(),
    transport: ReliableTransport(),
    diagnosticsReport: DiagnosticsReportService(),
    capabilities: _FakeCapabilityService(),
  );
}

Contact _trustedContact({TrustState trustState = TrustState.verified}) =>
    Contact(
      id: 'peer-1',
      name: 'Ala Tester',
      remoteName: 'Ala Tester',
      publicKey: base64Encode(List<int>.generate(32, (index) => index + 1)),
      trustState: trustState,
      lastSeen: DateTime(2026, 6, 19, 12),
      connected: true,
    );

class _FakeBleBridge extends BleBridge {
  final _events = StreamController<BleEvent>.broadcast();

  @override
  Stream<BleEvent> get events => _events.stream;

  @override
  Future<void> start({
    required String displayName,
    required String publicKey,
  }) async {}

  @override
  Future<void> scan() async {}

  @override
  Future<void> stopBackground() async {}

  @override
  Future<void> send(
    String peerId,
    String payload, {
    BlePriority priority = BlePriority.normal,
  }) async {}
}

class _FakeNotifications extends AppNotifications {
  @override
  Future<void> load() async {}

  @override
  Future<void> showMessage({
    required String title,
    required String body,
    required String messageId,
    required String threadId,
  }) async {}
}

class _FakeVoiceMessagingService extends VoiceMessagingService {
  @override
  Future<void> dispose() async {}
}

class _FakeCapabilityService extends CapabilityService {
  @override
  List<Permission> essentialPermissions() => const [];

  @override
  Future<List<CapabilityStatusItem>> loadStatus({
    required bool bluetoothRunning,
  }) async => [
    CapabilityStatusItem(
      label: 'Połączenia w pobliżu',
      status: bluetoothRunning ? 'aktywny' : 'nieaktywny',
      good: bluetoothRunning,
      fix: bluetoothRunning
          ? 'Gotowe do parowania i odbioru.'
          : 'Uruchom połączenia w aplikacji.',
    ),
  ];
}
