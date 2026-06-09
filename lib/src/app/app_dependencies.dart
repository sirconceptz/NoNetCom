part of '../../main.dart';

class AppDependencies {
  AppDependencies({
    required this.store,
    required this.crypto,
    required this.ble,
    required this.security,
    required this.diagnostics,
    required this.notifications,
    required this.voice,
    required this.transport,
    required this.diagnosticsReport,
    required this.capabilities,
  });

  factory AppDependencies.create() => AppDependencies(
    store: ChatStore(),
    crypto: ChatCrypto(),
    ble: BleBridge(),
    security: AppSecurity(),
    diagnostics: DiagnosticLog(),
    notifications: AppNotifications(),
    voice: VoiceMessagingService(),
    transport: ReliableTransport(),
    diagnosticsReport: DiagnosticsReportService(),
    capabilities: CapabilityService(),
  );

  final ChatStore store;
  final ChatCrypto crypto;
  final BleBridge ble;
  final AppSecurity security;
  final DiagnosticLog diagnostics;
  final AppNotifications notifications;
  final VoiceMessagingService voice;
  final ReliableTransport transport;
  final DiagnosticsReportService diagnosticsReport;
  final CapabilityService capabilities;
}
