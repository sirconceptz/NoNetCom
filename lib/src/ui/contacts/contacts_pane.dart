part of '../../../main.dart';

class _ContactsPane extends StatelessWidget {
  const _ContactsPane({
    required this.threads,
    required this.selectedThreadId,
    required this.profileName,
    required this.searchController,
    required this.status,
    required this.bluetoothRunning,
    required this.scanning,
    required this.onEditProfile,
    required this.onScan,
    required this.onOpenConnectionHelp,
    required this.onCreateGroup,
    required this.onSelect,
    required this.onRename,
  });

  final List<ChatThread> threads;
  final String? selectedThreadId;
  final String profileName;
  final TextEditingController searchController;
  final String status;
  final bool bluetoothRunning;
  final bool scanning;
  final Future<void> Function() onEditProfile;
  final Future<void> Function() onScan;
  final Future<void> Function() onOpenConnectionHelp;
  final Future<void> Function() onCreateGroup;
  final ValueChanged<String> onSelect;
  final ValueChanged<ChatThread> onRename;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final compactHeight = MediaQuery.sizeOf(context).height < 640;
    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        12,
        compact ? 12 : 16,
        compact ? 12 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                child: Icon(
                  bluetoothRunning
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      bluetoothRunning
                          ? 'Widoczny w pobliżu'
                          : 'Bluetooth wyłączony',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edytuj swoją nazwę',
                onPressed: onEditProfile,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              hintText: 'Szukaj rozmów',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          if (!bluetoothRunning)
            _FlowHint(
              icon: Icons.bluetooth_disabled,
              title: 'Najpierw włącz połączenia',
              body:
                  'Bez tego nie znajdziesz osób w pobliżu. Użyj „Szukaj”, a aplikacja spróbuje uruchomić połączenie.',
              action: TextButton.icon(
                onPressed: onOpenConnectionHelp,
                icon: const Icon(Icons.help_outline),
                label: const Text('Co sprawdzić?'),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: scanning ? null : onScan,
                  icon: scanning
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_search_outlined),
                  label: Text(scanning ? 'Szukam...' : 'Szukaj'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Utwórz grupę do 6 osób',
                onPressed: onCreateGroup,
                icon: const Icon(Icons.group_add_outlined),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenConnectionHelp,
              icon: const Icon(Icons.help_outline),
              label: const Text('Nie widzisz kontaktu?'),
            ),
          ),
          if (status.isNotEmpty) ...[
            SizedBox(height: compact ? 6 : 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
    final emptyState = _EmptyState(
      icon: Icons.bluetooth_searching,
      title: 'Znajdź pierwszą osobę',
      message: 'Włącz Bluetooth na obu telefonach i ustaw je blisko siebie.',
      action: FilledButton.icon(
        onPressed: scanning ? null : onScan,
        icon: const Icon(Icons.person_search_outlined),
        label: const Text('Szukaj osób'),
      ),
    );

    if (compactHeight) {
      return SafeArea(
        child: ListView(
          children: [
            header,
            const Divider(height: 1),
            if (threads.isEmpty)
              SizedBox(height: 260, child: emptyState)
            else
              for (final thread in threads)
                _ThreadListItem(
                  thread: thread,
                  selected: thread.id == selectedThreadId,
                  onTap: () => onSelect(thread.id),
                  onRename: () => onRename(thread),
                ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          header,
          const Divider(height: 1),
          Expanded(
            child: threads.isEmpty
                ? emptyState
                : ListView.builder(
                    itemCount: threads.length,
                    itemBuilder: (context, index) {
                      final thread = threads[index];
                      return _ThreadListItem(
                        thread: thread,
                        selected: thread.id == selectedThreadId,
                        onTap: () => onSelect(thread.id),
                        onRename: () => onRename(thread),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ThreadListItem extends StatelessWidget {
  const _ThreadListItem({
    required this.thread,
    required this.selected,
    required this.onTap,
    required this.onRename,
  });

  final ChatThread thread;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final contact = thread.contact;
    final compact = MediaQuery.sizeOf(context).width < 360;
    return ListTile(
      dense: compact,
      contentPadding: EdgeInsets.only(
        left: compact ? 12 : 16,
        right: compact ? 4 : 8,
      ),
      selected: selected,
      leading: _ThreadAvatar(thread: thread),
      title: Text(thread.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        thread.isGroup
            ? '${thread.group!.memberIds.length} uczestników'
            : [
                contact!.connected ? 'online' : 'offline',
                contact.trustLabel,
                _clock(contact.lastSeen),
              ].join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: 'Edytuj nazwę',
        icon: const Icon(Icons.edit_outlined),
        onPressed: onRename,
      ),
      onTap: onTap,
    );
  }
}
