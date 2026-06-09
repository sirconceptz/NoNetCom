part of '../../../main.dart';

class _OnboardingPane extends StatelessWidget {
  const _OnboardingPane({
    required this.profileName,
    required this.nameController,
    required this.bluetoothRunning,
    required this.onSaveName,
    required this.onRequestPermissions,
    required this.onOpenSettings,
    required this.onStartBluetooth,
    required this.onScan,
    required this.onFinish,
  });

  final String profileName;
  final TextEditingController nameController;
  final bool bluetoothRunning;
  final Future<void> Function() onSaveName;
  final Future<void> Function() onRequestPermissions;
  final Future<bool> Function() onOpenSettings;
  final Future<void> Function() onStartBluetooth;
  final Future<void> Function() onScan;
  final Future<void> Function() onFinish;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('NoNetCom')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Start offline',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'NoNetCom działa bez internetu przez Bluetooth. W samolocie włącz tryb samolotowy, a potem ręcznie włącz Bluetooth.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                _OnboardingStep(
                  number: 1,
                  icon: Icons.badge_outlined,
                  title: 'Nazwa profilu',
                  body:
                      'Ta nazwa jest pokazywana osobom w pobliżu podczas parowania. Możesz ją zmienić później.',
                  trailing: TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Nazwa',
                      hintText: profileName,
                      suffixIcon: IconButton(
                        tooltip: 'Zapisz nazwę',
                        onPressed: onSaveName,
                        icon: const Icon(Icons.save_outlined),
                      ),
                    ),
                  ),
                ),
                _OnboardingStep(
                  number: 2,
                  icon: Icons.settings_bluetooth,
                  title: 'Uprawnienia Bluetooth',
                  body:
                      'Aplikacja potrzebuje Bluetooth, skanowania, powiadomień i mikrofonu do wiadomości głosowych 1:1. Android może pytać też o uprawnienia powiązane ze skanowaniem BLE.',
                  actions: [
                    FilledButton.icon(
                      onPressed: onRequestPermissions,
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Poproś o uprawnienia'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenSettings,
                      icon: const Icon(Icons.tune_outlined),
                      label: const Text('Ustawienia systemowe'),
                    ),
                  ],
                ),
                _OnboardingStep(
                  number: 3,
                  icon: bluetoothRunning
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  title: 'Bluetooth LE',
                  body:
                      'Po uruchomieniu aplikacja zacznie nasłuchiwać kontaktów i reklamować Twoją obecność lokalnie.',
                  actions: [
                    FilledButton.icon(
                      onPressed: onStartBluetooth,
                      icon: Icon(
                        bluetoothRunning
                            ? Icons.check_circle_outline
                            : Icons.power_settings_new,
                      ),
                      label: Text(
                        bluetoothRunning
                            ? 'Bluetooth aktywny'
                            : 'Uruchom Bluetooth',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onScan,
                      icon: const Icon(Icons.radar),
                      label: const Text('Skanuj kontakty'),
                    ),
                  ],
                ),
                _OnboardingStep(
                  number: 4,
                  icon: Icons.enhanced_encryption_outlined,
                  title: 'Weryfikacja zaufania',
                  body:
                      'Po znalezieniu kontaktu porównaj kod bezpieczeństwa lub QR. Aplikacja ostrzeże, gdy klucz kontaktu się zmieni.',
                  actions: [
                    FilledButton.icon(
                      onPressed: onFinish,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Przejdź do czatu'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
    this.trailing,
    this.actions = const [],
  });

  final int number;
  final IconData icon;
  final String title;
  final String body;
  final Widget? trailing;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final header = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: Text('$number'),
                  ),
                  const SizedBox(width: 12),
                  Icon(icon, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final content = <Widget>[
                header,
                if (trailing != null) ...[
                  const SizedBox(height: 14),
                  trailing!,
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ];
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: content,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: content,
              );
            },
          ),
        ),
      ),
    );
  }
}
