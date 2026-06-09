// ignore_for_file: invalid_use_of_protected_member

part of '../../../main.dart';

extension _ContactsController on _ChatShellState {
  Future<void> _verifyContact(Contact contact) async {
    if (contact.publicKey == null) return;
    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zweryfikuj klucz'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: jsonEncode({
                'app': 'NoNetCom',
                'name': contact.name,
                'publicKey': contact.publicKey,
                'code': contact.safetyCode,
              }),
              size: 180,
            ),
            const SizedBox(height: 12),
            Text(
              contact.safetyCode,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Porównaj ten kod z kodem na drugim telefonie lub zeskanuj QR.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kody zgodne'),
          ),
        ],
      ),
    );
    if (verified == true) {
      await _store.verifyContact(contact.id);
      await _recordDiagnostic('contact_verified', 'Zweryfikowano kontakt');
      setState(() => _status = 'Klucz kontaktu zweryfikowany');
    }
  }

  Future<void> _renameContact(Contact contact) async {
    final controller = TextEditingController(text: contact.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nazwa kontaktu'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nazwa lokalna'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) {
      return;
    }
    await _store.renameContact(contact.id, name);
    await _recordDiagnostic('contact_renamed', 'Zmieniono nazwę kontaktu');
    setState(() => _status = 'Zmieniono nazwę kontaktu');
  }

  Future<void> _renameThread(ChatThread thread) async {
    if (thread.contact != null) {
      await _renameContact(thread.contact!);
      return;
    }
    final group = thread.group;
    if (group == null) return;
    final controller = TextEditingController(text: group.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nazwa grupy'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nazwa lokalna'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    await _store.renameGroup(group.id, name);
    setState(() => _status = 'Zmieniono nazwę grupy');
  }

  Future<void> _createGroup() async {
    final availableContacts = _store.contacts
        .where((contact) => contact.publicKey != null)
        .toList();
    if (availableContacts.length < 2) {
      setState(
        () => _status = 'Do grupy potrzeba co najmniej 2 kontaktów z kluczami',
      );
      return;
    }
    final nameController = TextEditingController(text: 'Grupa offline');
    final selectedIds = <String>{};
    final created = await showDialog<ChatGroup>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nowa grupa'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nazwa grupy'),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Uczestnicy: ${selectedIds.length}/$_maxGroupMembers',
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final contact in availableContacts)
                        CheckboxListTile(
                          value: selectedIds.contains(contact.id),
                          title: Text(contact.name),
                          subtitle: Text(contact.trustLabel),
                          onChanged:
                              selectedIds.length >= _maxGroupMembers &&
                                  !selectedIds.contains(contact.id)
                              ? null
                              : (checked) {
                                  setDialogState(() {
                                    if (checked == true) {
                                      selectedIds.add(contact.id);
                                    } else {
                                      selectedIds.remove(contact.id);
                                    }
                                  });
                                },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: selectedIds.length < 2
                  ? null
                  : () => Navigator.pop(
                      context,
                      ChatGroup(
                        id: _newId(),
                        name: nameController.text.trim().isEmpty
                            ? 'Grupa offline'
                            : nameController.text.trim(),
                        memberIds: selectedIds.toList(),
                        createdAt: DateTime.now(),
                      ),
                    ),
              child: const Text('Utwórz'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    if (created == null) return;
    await _store.upsertGroup(created);
    setState(() {
      _selectedThreadId = created.threadId;
      _status = 'Utworzono grupę ${created.name}';
    });
  }

  Future<void> _openGroupInfo(ChatGroup group) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final members = group.memberIds
            .map(_store.contact)
            .whereType<Contact>()
            .toList();
        return AlertDialog(
          title: Text(group.name),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${members.length} uczestników'),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final contact in members)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(child: Text(contact.initials)),
                          title: Text(contact.name),
                          subtitle: Text(
                            [
                              contact.connected ? 'online' : 'offline',
                              contact.trustLabel,
                            ].join(' • '),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Zamknij'),
            ),
            TextButton.icon(
              onPressed: () => _deleteGroupFromDialog(dialogContext, group),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Usuń lokalnie'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteGroupFromDialog(
    BuildContext dialogContext,
    ChatGroup group,
  ) async {
    final confirmed = await _confirmDestructive(
      title: 'Usunąć grupę?',
      body:
          'Usunie to lokalną grupę, jej historię i oczekujące potwierdzenia. Nie usuwa kontaktów.',
    );
    if (confirmed != true) return;
    final messageIds = _store
        .messagesFor(group.threadId)
        .map((message) => message.id)
        .toSet();
    _groupDeliveries.removeWhere(
      (_, delivery) => messageIds.contains(delivery.messageId),
    );
    await _store.savePendingGroupDeliveries(_groupDeliveries);
    await _store.deleteGroup(group.id);
    _selectedThreadId = null;
    await _recordDiagnostic('group_deleted', 'Usunięto grupę ${group.name}');
    setState(() => _status = 'Grupa usunięta lokalnie');
    if (dialogContext.mounted) Navigator.pop(dialogContext);
  }
}
