part of '../../main.dart';

class DiagnosticsSnapshot {
  const DiagnosticsSnapshot({
    required this.bluetoothRunning,
    required this.scanning,
    required this.contactsCount,
    required this.connectedContactsCount,
    required this.messagesCount,
    required this.pendingPackets,
    required this.outboundTransfers,
    required this.inboundTransfers,
    required this.status,
    required this.events,
  });

  final bool bluetoothRunning;
  final bool scanning;
  final int contactsCount;
  final int connectedContactsCount;
  final int messagesCount;
  final int pendingPackets;
  final int outboundTransfers;
  final int inboundTransfers;
  final String status;
  final List<DiagnosticEntry> events;

  Map<String, dynamic> toJson() => {
    'app': _serviceName,
    'createdAt': DateTime.now().toIso8601String(),
    'privacy': 'Raport nie zawiera tresci wiadomosci ani zawartosci plikow.',
    'bluetoothRunning': bluetoothRunning,
    'scanning': scanning,
    'contactsCount': contactsCount,
    'connectedContactsCount': connectedContactsCount,
    'messagesCount': messagesCount,
    'pendingPackets': pendingPackets,
    'outboundTransfers': outboundTransfers,
    'inboundTransfers': inboundTransfers,
    'status': status,
    'events': events.map((entry) => entry.toJson()).toList(),
  };
}

class DiagnosticsReportService {
  Future<File> export(DiagnosticsSnapshot snapshot) async {
    final directory = await getApplicationDocumentsDirectory();
    final reportDir = Directory('${directory.path}/NoNetCom');
    if (!reportDir.existsSync()) reportDir.createSync(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File('${reportDir.path}/nonetcom-diagnostics-$stamp.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
    );
    return file;
  }

  String asLogSection(DiagnosticsSnapshot snapshot) =>
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'diagnosticsIncluded': true, ...snapshot.toJson()});
}
