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
  final Future<void> Function() onCreateGroup;
  final ValueChanged<String> onSelect;
  final ValueChanged<ChatThread> onRename;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: scanning ? null : onScan,
                        icon: scanning
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.person_search_outlined),
                        label: Text(scanning ? 'Szukam...' : 'Znajdź osoby'),
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
                if (status.isNotEmpty) ...[
                  const SizedBox(height: 10),
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
          ),
          const Divider(height: 1),
          Expanded(
            child: threads.isEmpty
                ? const _EmptyState(
                    icon: Icons.bluetooth_searching,
                    message:
                        'Brak kontaktów. Włącz Bluetooth na obu telefonach i rozpocznij skanowanie.',
                  )
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
    return ListTile(
      selected: selected,
      leading: _ThreadAvatar(thread: thread),
      title: Text(thread.name),
      subtitle: Text(
        thread.isGroup
            ? '${thread.group!.memberIds.length} uczestników'
            : [
                contact!.connected ? 'online' : 'offline',
                contact.trustLabel,
                _clock(contact.lastSeen),
              ].join(' • '),
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
