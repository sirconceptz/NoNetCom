part of '../../../main.dart';

class _ContactsPane extends StatelessWidget {
  const _ContactsPane({
    required this.threads,
    required this.selectedThreadId,
    required this.nameController,
    required this.searchController,
    required this.status,
    required this.onSaveName,
    required this.onScan,
    required this.onCreateGroup,
    required this.onSelect,
    required this.onRename,
  });

  final List<ChatThread> threads;
  final String? selectedThreadId;
  final TextEditingController nameController;
  final TextEditingController searchController;
  final String status;
  final Future<void> Function() onSaveName;
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Twoja nazwa',
                    suffixIcon: IconButton(
                      tooltip: 'Zapisz nazwę',
                      icon: const Icon(Icons.check),
                      onPressed: onSaveName,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    labelText: 'Szukaj kontaktów',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onScan,
                  icon: const Icon(Icons.travel_explore),
                  label: const Text('Znajdź osoby w pobliżu'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onCreateGroup,
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Utwórz grupę do 6 osób'),
                ),
                const SizedBox(height: 12),
                Text(status, style: Theme.of(context).textTheme.bodySmall),
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
