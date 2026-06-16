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
        scaffoldBackgroundColor: const Color(0xFFF7FAF9),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide.none,
          ),
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
  bool _showMessageSearch = false;
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
        onFinish: _finishOnboarding,
        onSkip: _skipOnboarding,
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
    final isWideLayout = MediaQuery.sizeOf(context).width >= 760;
    final allMessages = selected == null
        ? <ChatMessage>[]
        : _store.messagesFor(selected.id);
    final messages = allMessages.where((message) {
      final query = _messageQuery.toLowerCase();
      return query.isEmpty ||
          message.text.toLowerCase().contains(query) ||
          (message.fileName ?? '').toLowerCase().contains(query);
    }).toList();

    return PopScope(
      canPop: selected == null || isWideLayout,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selected != null && !isWideLayout) {
          setState(() {
            _selectedThreadId = null;
            _showMessageSearch = false;
            _messageSearchController.clear();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            selected != null && !isWideLayout ? 'Rozmowa' : 'NoNetCom',
          ),
          actions: [
            if (selected == null || isWideLayout)
              IconButton(
                tooltip: 'Znajdź osoby w pobliżu',
                onPressed: _scanning ? null : _scan,
                icon: _scanning
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_search_outlined),
              ),
            PopupMenuButton<_MainMenuAction>(
              tooltip: 'Menu aplikacji',
              onSelected: _handleMainMenuAction,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _MainMenuAction.bluetooth,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _bluetoothRunning
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                    ),
                    title: const Text('Bluetooth'),
                    subtitle: Text(
                      _bluetoothRunning ? 'Uruchomiony' : 'Uruchom',
                    ),
                  ),
                ),
                const PopupMenuItem(
                  value: _MainMenuAction.security,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.shield_outlined),
                    title: Text('Bezpieczeństwo'),
                  ),
                ),
                const PopupMenuItem(
                  value: _MainMenuAction.settings,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.settings_outlined),
                    title: Text('Ustawienia'),
                  ),
                ),
                const PopupMenuItem(
                  value: _MainMenuAction.about,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline),
                    title: Text('O aplikacji'),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Builder(
                builder: (context) {
                  final contactsPane = _ContactsPane(
                    threads: threads,
                    selectedThreadId: _selectedThreadId,
                    profileName: _store.profileName,
                    searchController: _contactSearchController,
                    status: _status,
                    bluetoothRunning: _bluetoothRunning,
                    scanning: _scanning,
                    onEditProfile: _editProfileName,
                    onScan: _scan,
                    onCreateGroup: _createGroup,
                    onSelect: (id) => setState(() {
                      _selectedThreadId = id;
                      _showMessageSearch = false;
                      _messageSearchController.clear();
                    }),
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
                    onBack: isWideLayout
                        ? null
                        : () => setState(() {
                            _selectedThreadId = null;
                            _showMessageSearch = false;
                            _messageSearchController.clear();
                          }),
                    showSearch: _showMessageSearch,
                    onToggleSearch: () => setState(() {
                      _showMessageSearch = !_showMessageSearch;
                      if (!_showMessageSearch) {
                        _messageSearchController.clear();
                      }
                    }),
                    onEmoji: (emoji) {
                      _messageController.text =
                          '${_messageController.text}$emoji';
                      _messageController.selection = TextSelection.collapsed(
                        offset: _messageController.text.length,
                      );
                    },
                  );

                  if (isWideLayout) {
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
      ),
    );
  }

  void _handleMainMenuAction(_MainMenuAction action) {
    switch (action) {
      case _MainMenuAction.bluetooth:
        unawaited(_startBluetooth());
        return;
      case _MainMenuAction.security:
        unawaited(_openSecurityCenter());
        return;
      case _MainMenuAction.settings:
        unawaited(_openSettings());
        return;
      case _MainMenuAction.about:
        unawaited(_openAboutApp());
        return;
    }
  }
}

enum _MainMenuAction { bluetooth, security, settings, about }
