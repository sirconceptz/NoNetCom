part of '../../main.dart';

class DiagnosticLog {
  static const _eventsKey = 'diagnosticEvents';
  static const _maxEntries = 300;

  late SharedPreferences _prefs;
  final List<DiagnosticEntry> entries = [];

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    entries
      ..clear()
      ..addAll(
        (_prefs.getStringList(_eventsKey) ?? []).map(
          (json) => DiagnosticEntry.fromJson(
            jsonDecode(json) as Map<String, dynamic>,
          ),
        ),
      );
  }

  Future<void> add(DiagnosticEntry entry) async {
    entries.add(entry);
    if (entries.length > _maxEntries) {
      entries.removeRange(0, entries.length - _maxEntries);
    }
    await _save();
  }

  Future<void> clear() async {
    entries.clear();
    await _prefs.remove(_eventsKey);
  }

  Future<void> _save() async {
    await _prefs.setStringList(
      _eventsKey,
      entries.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }
}

class DiagnosticEntry {
  const DiagnosticEntry({
    required this.type,
    required this.message,
    required this.level,
    required this.createdAt,
  });

  final String type;
  final String message;
  final DiagnosticLevel level;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'type': type,
    'message': message,
    'level': level.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DiagnosticEntry.fromJson(Map<String, dynamic> json) =>
      DiagnosticEntry(
        type: json['type'] as String,
        message: json['message'] as String,
        level: DiagnosticLevel.values.firstWhere(
          (level) => level.name == json['level'],
          orElse: () => DiagnosticLevel.info,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

enum DiagnosticLevel { info, warning, error }
