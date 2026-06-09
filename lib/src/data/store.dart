part of '../../main.dart';

class ChatStore {
  static const _profileKey = 'profileName';
  static const _contactsKey = 'contacts';
  static const _groupsKey = 'groups';
  static const _messagesKey = 'messages';
  static const _pendingOutboundFilesKey = 'pendingOutboundFiles';
  static const _pendingGroupDeliveriesKey = 'pendingGroupDeliveries';
  static const _onboardingSeenKey = 'onboardingSeen';
  static const _includeDiagnosticsInErrorReportKey =
      'includeDiagnosticsInErrorReport';

  late SharedPreferences _prefs;
  String profileName = 'Podróżny ${Random().nextInt(899) + 100}';
  bool onboardingSeen = false;
  bool includeDiagnosticsInErrorReport = false;
  final List<Contact> contacts = [];
  final List<ChatGroup> groups = [];
  final List<ChatMessage> messages = [];
  final Map<String, OutboundFileTransfer> pendingOutboundFiles = {};
  final Map<String, OutboundGroupDelivery> pendingGroupDeliveries = {};

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    profileName = _prefs.getString(_profileKey) ?? profileName;
    onboardingSeen = _prefs.getBool(_onboardingSeenKey) ?? false;
    includeDiagnosticsInErrorReport =
        _prefs.getBool(_includeDiagnosticsInErrorReportKey) ?? false;
    contacts
      ..clear()
      ..addAll(
        (_prefs.getStringList(_contactsKey) ?? []).map(
          (json) => Contact.fromJson(jsonDecode(json) as Map<String, dynamic>),
        ),
      );
    groups
      ..clear()
      ..addAll(
        (_prefs.getStringList(_groupsKey) ?? []).map(
          (json) =>
              ChatGroup.fromJson(jsonDecode(json) as Map<String, dynamic>),
        ),
      );
    messages
      ..clear()
      ..addAll(
        (_prefs.getStringList(_messagesKey) ?? []).map(
          (json) =>
              ChatMessage.fromJson(jsonDecode(json) as Map<String, dynamic>),
        ),
      );
    pendingOutboundFiles
      ..clear()
      ..addEntries(
        (_prefs.getStringList(_pendingOutboundFilesKey) ?? []).map((json) {
          final transfer = OutboundFileTransfer.fromJson(
            jsonDecode(json) as Map<String, dynamic>,
          );
          return MapEntry(transfer.transferId, transfer);
        }),
      );
    pendingGroupDeliveries
      ..clear()
      ..addEntries(
        (_prefs.getStringList(_pendingGroupDeliveriesKey) ?? []).map((json) {
          final map = jsonDecode(json) as Map<String, dynamic>;
          return MapEntry(
            map['packetId'] as String,
            OutboundGroupDelivery.fromJson(map),
          );
        }),
      );
  }

  Contact? contact(String id) =>
      contacts.where((contact) => contact.id == id).firstOrNull;

  List<ChatMessage> messagesFor(String threadId) {
    final legacyContactId = threadId.startsWith('contact:')
        ? threadId.substring('contact:'.length)
        : null;
    return messages
        .where(
          (message) =>
              message.contactId == threadId ||
              (legacyContactId != null && message.contactId == legacyContactId),
        )
        .toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  Future<void> setProfileName(String name) async {
    profileName = name;
    await _prefs.setString(_profileKey, name);
  }

  Future<void> markOnboardingSeen() async {
    onboardingSeen = true;
    await _prefs.setBool(_onboardingSeenKey, true);
  }

  Future<void> setIncludeDiagnosticsInErrorReport(bool value) async {
    includeDiagnosticsInErrorReport = value;
    await _prefs.setBool(_includeDiagnosticsInErrorReportKey, value);
  }

  Future<void> upsertContact(Contact contact) async {
    final index = contacts.indexWhere((item) => item.id == contact.id);
    if (index == -1) {
      contacts.add(contact);
    } else {
      final current = contacts[index];
      final incomingKey = contact.publicKey ?? current.publicKey;
      final keyChanged =
          current.trustState == TrustState.verified &&
          contact.publicKey != null &&
          current.publicKey != null &&
          contact.publicKey != current.publicKey;
      contacts[index] = current.copyWith(
        remoteName: contact.remoteName,
        publicKey: incomingKey,
        lastSeen: contact.lastSeen,
        connected: contact.connected,
        trustState: keyChanged ? TrustState.keyChanged : current.trustState,
      );
    }
    await _saveContacts();
  }

  Future<void> renameContact(String id, String name) async {
    final index = contacts.indexWhere((contact) => contact.id == id);
    if (index == -1) return;
    contacts[index] = contacts[index].copyWith(name: name);
    await _saveContacts();
  }

  Future<void> verifyContact(String id) async {
    final index = contacts.indexWhere((contact) => contact.id == id);
    if (index == -1) return;
    contacts[index] = contacts[index].copyWith(trustState: TrustState.verified);
    await _saveContacts();
  }

  Future<void> upsertGroup(ChatGroup group) async {
    final index = groups.indexWhere((item) => item.id == group.id);
    if (index == -1) {
      groups.add(group);
    } else {
      groups[index] = groups[index].copyWith(
        name: group.name,
        memberIds: group.memberIds,
      );
    }
    await _saveGroups();
  }

  Future<void> renameGroup(String id, String name) async {
    final index = groups.indexWhere((group) => group.id == id);
    if (index == -1) return;
    groups[index] = groups[index].copyWith(name: name);
    await _saveGroups();
  }

  Future<void> deleteGroup(String id) async {
    final threadId = ChatGroup.threadIdFor(id);
    groups.removeWhere((group) => group.id == id);
    messages.removeWhere((message) => message.contactId == threadId);
    await _saveGroups();
    await _saveMessages();
  }

  Future<void> setContactConnected(String id, bool connected) async {
    final index = contacts.indexWhere((contact) => contact.id == id);
    if (index == -1) return;
    contacts[index] = contacts[index].copyWith(connected: connected);
    await _saveContacts();
  }

  Future<void> _saveContacts() async {
    contacts.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    await _prefs.setStringList(
      _contactsKey,
      contacts.map((contact) => jsonEncode(contact.toJson())).toList(),
    );
  }

  Future<void> _saveGroups() async {
    groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _prefs.setStringList(
      _groupsKey,
      groups.map((group) => jsonEncode(group.toJson())).toList(),
    );
  }

  Future<void> addMessage(ChatMessage message) async {
    messages.add(message);
    await _saveMessages();
  }

  Future<void> updateMessageStatus(String id, MessageStatus status) async {
    final index = messages.indexWhere((message) => message.id == id);
    if (index == -1) return;
    messages[index] = messages[index].copyWith(status: status);
    await _saveMessages();
  }

  Future<void> updateMessageProgress(String id, double progress) async {
    final index = messages.indexWhere((message) => message.id == id);
    if (index == -1) return;
    messages[index] = messages[index].copyWith(progress: progress.clamp(0, 1));
    await _saveMessages();
  }

  Future<void> clearMessages() async {
    messages.clear();
    pendingOutboundFiles.clear();
    pendingGroupDeliveries.clear();
    await _prefs.remove(_messagesKey);
    await _prefs.remove(_pendingOutboundFilesKey);
    await _prefs.remove(_pendingGroupDeliveriesKey);
  }

  Future<void> clearContacts() async {
    contacts.clear();
    groups.clear();
    await _prefs.remove(_contactsKey);
    await _prefs.remove(_groupsKey);
  }

  Map<String, dynamic> exportTrustedContactsBackup() {
    final trusted = contacts
        .where(
          (contact) =>
              contact.trustState == TrustState.verified &&
              contact.publicKey != null &&
              contact.publicKey!.trim().isNotEmpty,
        )
        .map(
          (contact) => {
            'id': contact.id,
            'name': contact.name,
            'remoteName': contact.remoteName,
            'publicKey': contact.publicKey,
            'trustState': contact.trustState.name,
            'lastSeen': contact.lastSeen.toIso8601String(),
          },
        )
        .toList();
    return {
      'type': 'nonetcom-trusted-contacts',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'privacy':
          'Ten plik zawiera publiczne klucze i lokalne nazwy zaufanych kontaktow. Nie zawiera prywatnej tozsamosci E2EE.',
      'contactsCount': trusted.length,
      'contacts': trusted,
    };
  }

  Future<int> importTrustedContactsBackup(Map<String, dynamic> backup) async {
    if (backup['type'] != 'nonetcom-trusted-contacts') {
      throw const FormatException('To nie jest backup kontaktów NoNetCom');
    }
    if (backup['version'] != 1) {
      throw const FormatException('Nieobsługiwana wersja backupu kontaktów');
    }
    final rawContacts = backup['contacts'];
    if (rawContacts is! List) {
      throw const FormatException('Backup nie zawiera listy kontaktów');
    }
    var imported = 0;
    for (final raw in rawContacts) {
      if (raw is! Map) continue;
      final id = raw['id'] as String?;
      final name = raw['name'] as String?;
      final publicKey = raw['publicKey'] as String?;
      if (id == null ||
          id.trim().isEmpty ||
          name == null ||
          name.trim().isEmpty ||
          publicKey == null ||
          publicKey.trim().isEmpty) {
        continue;
      }
      final contact = Contact(
        id: id,
        name: name,
        remoteName: raw['remoteName'] as String?,
        publicKey: publicKey,
        trustState: TrustState.verified,
        lastSeen:
            DateTime.tryParse(raw['lastSeen'] as String? ?? '') ??
            DateTime.now(),
      );
      final index = contacts.indexWhere((item) => item.id == contact.id);
      if (index == -1) {
        contacts.add(contact);
      } else {
        final current = contacts[index];
        contacts[index] = current.copyWith(
          name: contact.name,
          remoteName: contact.remoteName,
          publicKey: contact.publicKey,
          trustState: contact.trustState,
          lastSeen: contact.lastSeen,
          connected: current.connected,
        );
      }
      imported++;
    }
    await _saveContacts();
    return imported;
  }

  Future<void> _saveMessages() async {
    await _prefs.setStringList(
      _messagesKey,
      messages.map((message) => jsonEncode(message.toJson())).toList(),
    );
  }

  Future<void> savePendingOutboundFiles(
    Map<String, OutboundFileTransfer> transfers,
  ) async {
    pendingOutboundFiles
      ..clear()
      ..addAll(transfers);
    await _prefs.setStringList(
      _pendingOutboundFilesKey,
      transfers.values.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> savePendingGroupDeliveries(
    Map<String, OutboundGroupDelivery> deliveries,
  ) async {
    pendingGroupDeliveries
      ..clear()
      ..addAll(deliveries);
    await _prefs.setStringList(
      _pendingGroupDeliveriesKey,
      deliveries.entries
          .map(
            (entry) =>
                jsonEncode({'packetId': entry.key, ...entry.value.toJson()}),
          )
          .toList(),
    );
  }
}
