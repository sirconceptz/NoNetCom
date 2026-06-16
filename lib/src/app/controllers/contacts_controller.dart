// ignore_for_file: invalid_use_of_protected_member

part of '../../../main.dart';

extension _ContactsController on _ChatShellState {
  Future<void> _verifyContact(Contact contact) async {
    if (contact.publicKey == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Zweryfikuj: ${contact.name}',
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Jedna osoba pokazuje swój kod, druga go skanuje. Potem zamieńcie się rolami, aby obie strony oznaczyły kontakt jako zaufany.',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _showOwnVerificationQr(contact);
                },
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Pokaż mój kod'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _scanContactVerificationQr(contact);
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Skanuj kod kontaktu'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _compareSafetyCode(contact);
                },
                icon: const Icon(Icons.pin_outlined),
                label: const Text('Porównaj kod ręcznie'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOwnVerificationQr(Contact contact) async {
    final payload = VerificationQrPayload(
      profileName: _store.profileName,
      publicKey: base64Encode(_crypto.cachedPublicKey),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mój kod weryfikacyjny'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: payload.encode(), size: 220),
            const SizedBox(height: 12),
            Text(
              _store.profileName,
              style: Theme.of(dialogContext).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              payload.safetyCode,
              style: Theme.of(dialogContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Poproś ${contact.name}, aby wybrał „Skanuj kod kontaktu”.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanContactVerificationQr(Contact contact) async {
    final rawValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _QrScannerPage(contactName: contact.name),
      ),
    );
    if (!mounted || rawValue == null) return;

    final payload = VerificationQrPayload.tryParse(rawValue);
    if (payload == null) {
      await _showVerificationError(
        'Nieprawidłowy kod',
        'Ten kod QR nie jest kodem weryfikacyjnym NoNetCom.',
      );
      return;
    }
    if (!payload.matches(contact)) {
      await _recordDiagnostic(
        'contact_verification_mismatch',
        'Kod QR nie pasuje do zapisanego klucza kontaktu',
        level: DiagnosticLevel.warning,
      );
      await _showVerificationError(
        'Klucze nie są zgodne',
        'Kod należy do profilu „${payload.profileName}”, ale nie pasuje do klucza zapisanego dla ${contact.name}. Nie oznaczono kontaktu jako zaufanego.',
      );
      return;
    }
    await _markContactVerified(contact);
  }

  Future<void> _compareSafetyCode(Contact contact) async {
    final verified = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Porównaj kod'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Na telefonie kontaktu otwórz jego własny kod weryfikacyjny. Oba kody muszą być identyczne.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SelectableText(
              contact.safetyCode,
              style: Theme.of(dialogContext).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Kody są zgodne'),
          ),
        ],
      ),
    );
    if (verified == true) await _markContactVerified(contact);
  }

  Future<void> _markContactVerified(Contact contact) async {
    await _store.verifyContact(contact.id);
    await _recordDiagnostic('contact_verified', 'Zweryfikowano kontakt');
    if (!mounted) return;
    setState(() => _status = 'Kontakt ${contact.name} jest zweryfikowany');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Zweryfikowano kontakt ${contact.name}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showVerificationError(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.gpp_bad_outlined),
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Rozumiem'),
          ),
        ],
      ),
    );
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
