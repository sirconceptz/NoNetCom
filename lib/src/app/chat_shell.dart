part of '../../main.dart';

class OfflineChatApp extends StatelessWidget {
  const OfflineChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _serviceName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007A7A),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const ChatShell(),
    );
  }
}

class ChatShell extends StatefulWidget {
  const ChatShell({super.key, this.dependencies});

  final AppDependencies? dependencies;

  @override
  State<ChatShell> createState() => _ChatShellState();
}

class _ChatShellState extends State<ChatShell> {
  late final AppDependencies _dependencies;
  late final AppLifecycleCoordinator _lifecycleCoordinator;
  ChatStore get _store => _dependencies.store;
  ChatCrypto get _crypto => _dependencies.crypto;
  BleBridge get _ble => _dependencies.ble;
  AppSecurity get _security => _dependencies.security;
  DiagnosticLog get _diagnostics => _dependencies.diagnostics;
  AppNotifications get _notifications => _dependencies.notifications;
  VoiceMessagingService get _voice => _dependencies.voice;
  ReliableTransport get _transport => _dependencies.transport;
  DiagnosticsReportService get _diagnosticsReport =>
      _dependencies.diagnosticsReport;
  CapabilityService get _capabilities => _dependencies.capabilities;
  final _messageController = TextEditingController();
  final _nameController = TextEditingController();
  final _contactSearchController = TextEditingController();
  final _messageSearchController = TextEditingController();
  final Map<String, OutboundFileTransfer> _outboundFiles = {};
  final Map<String, InboundFileTransfer> _inboundFiles = {};
  final Map<String, OutboundGroupDelivery> _groupDeliveries = {};

  StreamSubscription<BleEvent>? _bleSubscription;
  Timer? _retryTimer;
  Timer? _voiceTimer;
  Timer? _liveVoiceTimer;
  bool _ready = false;
  bool _bluetoothRunning = false;
  bool _scanning = false;
  bool _locked = false;
  bool _showOnboarding = false;
  bool _recordingVoice = false;
  bool _liveVoiceSpeaking = false;
  bool _liveSegmentLoopRunning = false;
  bool _disposed = false;
  String? _selectedThreadId;
  String _status = 'Uruchamianie...';
  String _contactQuery = '';
  String _messageQuery = '';
  String? _voiceTargetContactId;
  Duration _voiceElapsed = Duration.zero;
  LiveVoiceSession? _liveVoiceSession;
  Duration _liveVoiceElapsed = Duration.zero;
  LiveVoiceQuality _liveVoiceQuality = LiveVoiceQuality.good;
  final Map<String, DateTime> _liveVoicePendingPackets = {};

  Contact? get _selectedContact => _store.contacts
      .where((contact) => contact.threadId == _selectedThreadId)
      .firstOrNull;

  ChatGroup? get _selectedGroup => _store.groups
      .where((group) => group.threadId == _selectedThreadId)
      .firstOrNull;

  ChatThread? get _selectedThread {
    final contact = _selectedContact;
    if (contact != null) return ChatThread.contact(contact);
    final group = _selectedGroup;
    if (group != null) return ChatThread.group(group);
    return null;
  }

  @override
  void initState() {
    super.initState();
    _dependencies = widget.dependencies ?? AppDependencies.create();
    _lifecycleCoordinator = AppLifecycleCoordinator(_handleLifecycleState)
      ..start();
    _contactSearchController.addListener(() {
      setState(() => _contactQuery = _contactSearchController.text.trim());
    });
    _messageSearchController.addListener(() {
      setState(() => _messageQuery = _messageSearchController.text.trim());
    });
    _boot();
  }

  @override
  void dispose() {
    _disposed = true;
    _bleSubscription?.cancel();
    _retryTimer?.cancel();
    _voiceTimer?.cancel();
    _liveVoiceTimer?.cancel();
    _lifecycleCoordinator.dispose();
    _transport.dispose();
    unawaited(_voice.dispose());
    for (final transfer in _inboundFiles.values) {
      transfer.file.closeSync();
    }
    _messageController.dispose();
    _nameController.dispose();
    _contactSearchController.dispose();
    _messageSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_locked) {
      return Scaffold(
        appBar: AppBar(title: const Text('NoNetCom')),
        body: Center(
          child: FilledButton.icon(
            onPressed: _unlock,
            icon: const Icon(Icons.lock_open),
            label: const Text('Odblokuj'),
          ),
        ),
      );
    }

    if (_showOnboarding) {
      return _OnboardingPane(
        profileName: _store.profileName,
        nameController: _nameController,
        bluetoothRunning: _bluetoothRunning,
        onSaveName: _saveName,
        onRequestPermissions: _requestEssentialPermissions,
        onOpenSettings: openAppSettings,
        onStartBluetooth: _startBluetooth,
        onScan: _scan,
        onFinish: _finishOnboarding,
      );
    }

    final threads =
        [
          ..._store.groups.map(ChatThread.group),
          ..._store.contacts.map(ChatThread.contact),
        ].where((thread) {
          final query = _contactQuery.toLowerCase();
          return query.isEmpty ||
              thread.name.toLowerCase().contains(query) ||
              (thread.contact?.remoteName ?? '').toLowerCase().contains(query);
        }).toList();
    final selected = _selectedThread;
    final allMessages = selected == null
        ? <ChatMessage>[]
        : _store.messagesFor(selected.id);
    final messages = allMessages.where((message) {
      final query = _messageQuery.toLowerCase();
      return query.isEmpty ||
          message.text.toLowerCase().contains(query) ||
          (message.fileName ?? '').toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('NoNetCom'),
        actions: [
          IconButton(
            tooltip: 'Skanuj',
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.radar),
          ),
          IconButton(
            tooltip: 'Bluetooth',
            onPressed: _startBluetooth,
            icon: Icon(
              _bluetoothRunning
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
            ),
          ),
          IconButton(
            tooltip: 'Bezpieczeństwo',
            onPressed: _openSecurityCenter,
            icon: const Icon(Icons.shield_outlined),
          ),
          IconButton(
            tooltip: 'Dane lokalne',
            onPressed: _openDataCenter,
            icon: const Icon(Icons.storage_outlined),
          ),
          IconButton(
            tooltip: 'Diagnostyka',
            onPressed: _openDiagnostics,
            icon: const Icon(Icons.monitor_heart_outlined),
          ),
          IconButton(
            tooltip: 'O aplikacji',
            onPressed: _openAboutApp,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final contactsPane = _ContactsPane(
                  threads: threads,
                  selectedThreadId: _selectedThreadId,
                  nameController: _nameController,
                  searchController: _contactSearchController,
                  status: _status,
                  onSaveName: _saveName,
                  onScan: _scan,
                  onCreateGroup: _createGroup,
                  onSelect: (id) => setState(() => _selectedThreadId = id),
                  onRename: _renameThread,
                );
                final chatPane = _ChatPane(
                  thread: selected,
                  messages: messages,
                  controller: _messageController,
                  searchController: _messageSearchController,
                  onSend: _sendMessage,
                  onAttach: _sendFile,
                  onVoice: _toggleVoiceRecording,
                  onCancelVoice: _cancelVoiceRecording,
                  onPlayVoice: _playVoiceMessage,
                  onStartLiveVoice: selected?.contact == null
                      ? null
                      : () => _startLiveVoiceSession(selected!.contact!),
                  recordingVoice: _recordingVoice,
                  voiceElapsed: _voiceElapsed,
                  onVerify: selected?.contact == null
                      ? null
                      : () => _verifyContact(selected!.contact!),
                  onRename: selected == null
                      ? null
                      : () => _renameThread(selected),
                  onGroupInfo: selected?.group == null
                      ? null
                      : () => _openGroupInfo(selected!.group!),
                  onEmoji: (emoji) {
                    _messageController.text =
                        '${_messageController.text}$emoji';
                    _messageController.selection = TextSelection.collapsed(
                      offset: _messageController.text.length,
                    );
                  },
                );

                if (wide) {
                  return Row(
                    children: [
                      SizedBox(width: 320, child: contactsPane),
                      const VerticalDivider(width: 1),
                      Expanded(child: chatPane),
                    ],
                  );
                }
                return selected == null ? contactsPane : chatPane;
              },
            ),
          ),
          if (_liveVoiceSession case final session?)
            _LiveVoicePanel(
              session: session,
              elapsed: _liveVoiceElapsed,
              quality: _liveVoiceQuality,
              speaking: _liveVoiceSpeaking,
              onAccept: _acceptLiveVoiceSession,
              onReject: () => _endLiveVoiceSession(reason: 'odrzucono'),
              onToggleSpeaking: _toggleLiveVoiceSpeaking,
              onEnd: () => _endLiveVoiceSession(reason: 'zakończono'),
            ),
        ],
      ),
    );
  }
}
