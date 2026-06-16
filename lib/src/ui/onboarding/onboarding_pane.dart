part of '../../../main.dart';

class _OnboardingPane extends StatefulWidget {
  const _OnboardingPane({
    required this.profileName,
    required this.nameController,
    required this.bluetoothRunning,
    required this.onSaveName,
    required this.onRequestPermissions,
    required this.onOpenSettings,
    required this.onStartBluetooth,
    required this.onFinish,
    required this.onSkip,
  });

  final String profileName;
  final TextEditingController nameController;
  final bool bluetoothRunning;
  final Future<void> Function() onSaveName;
  final Future<void> Function() onRequestPermissions;
  final Future<bool> Function() onOpenSettings;
  final Future<void> Function() onStartBluetooth;
  final Future<void> Function() onFinish;
  final Future<void> Function() onSkip;

  @override
  State<_OnboardingPane> createState() => _OnboardingPaneState();
}

class _OnboardingPaneState extends State<_OnboardingPane> {
  static const _pageCount = 4;

  final _pageController = PageController();
  int _page = 0;
  bool _busy = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_busy) return;
    if (_page == 1 && widget.nameController.text.trim().isNotEmpty) {
      setState(() => _busy = true);
      await widget.onSaveName();
      if (!mounted) return;
      setState(() => _busy = false);
    }
    if (_page == _pageCount - 1) {
      await widget.onFinish();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _back() {
    return _pageController.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pageCount - 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('NoNetCom'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _skip,
            child: const Text('Pomiń'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  const _OnboardingPage(
                    icon: Icons.forum_outlined,
                    title: 'Rozmawiaj bez internetu',
                    body:
                        'NoNetCom łączy telefony znajdujące się w pobliżu przez Bluetooth. Wiadomości pozostają na Twoich urządzeniach.',
                    note:
                        'W trybie samolotowym możesz ręcznie ponownie włączyć Bluetooth.',
                  ),
                  _OnboardingPage(
                    icon: Icons.badge_outlined,
                    title: 'Jak mają Cię widzieć inni?',
                    body:
                        'Ta nazwa będzie widoczna podczas wyszukiwania osób w pobliżu. Możesz ją później zmienić w ustawieniach.',
                    content: TextField(
                      controller: widget.nameController,
                      autofocus: false,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Twoja nazwa',
                        hintText: widget.profileName,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                  ),
                  _OnboardingPage(
                    icon: widget.bluetoothRunning
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_searching,
                    title: 'Znajdź osoby w pobliżu',
                    body:
                        'Bluetooth służy do wykrywania kontaktów i przesyłania rozmów. Powiadomienia informują o nowych wiadomościach, a mikrofon obsługuje głos.',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: widget.onRequestPermissions,
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('Przyznaj potrzebne zgody'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: widget.onStartBluetooth,
                          icon: Icon(
                            widget.bluetoothRunning
                                ? Icons.check_circle_outline
                                : Icons.bluetooth,
                          ),
                          label: Text(
                            widget.bluetoothRunning
                                ? 'Bluetooth jest gotowy'
                                : 'Uruchom Bluetooth',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: widget.onOpenSettings,
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text('Otwórz ustawienia systemowe'),
                        ),
                      ],
                    ),
                  ),
                  const _OnboardingPage(
                    icon: Icons.verified_user_outlined,
                    title: 'Potwierdzaj właściwą osobę',
                    body:
                        'Po dodaniu kontaktu zeskanujcie nawzajem swoje kody QR. Dzięki temu masz pewność, że szyfrowana rozmowa trafia do właściwej osoby.',
                    note:
                        'NoNetCom ostrzeże Cię, jeżeli klucz kontaktu kiedykolwiek się zmieni.',
                  ),
                ],
              ),
            ),
            _OnboardingProgress(current: _page, count: _pageCount),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: _page == 0
                          ? null
                          : IconButton.outlined(
                              tooltip: 'Poprzednia karta',
                              onPressed: _busy ? null : _back,
                              icon: const Icon(Icons.arrow_back),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _next,
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                isLast
                                    ? Icons.chat_bubble_outline
                                    : Icons.arrow_forward,
                              ),
                        label: Text(isLast ? 'Przejdź do rozmów' : 'Dalej'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    this.note,
    this.content,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? note;
  final Widget? content;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 34, color: scheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              if (content != null) ...[const SizedBox(height: 28), content!],
              if (note != null) ...[
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        note!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingProgress extends StatelessWidget {
  const _OnboardingProgress({required this.current, required this.count});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Krok ${current + 1} z $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < count; index++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: index == current ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: index == current
                    ? scheme.primary
                    : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
