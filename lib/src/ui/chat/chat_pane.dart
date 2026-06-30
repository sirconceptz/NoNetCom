part of '../../../main.dart';

class _ChatPane extends StatelessWidget {
  const _ChatPane({
    required this.thread,
    required this.messages,
    required this.controller,
    required this.searchController,
    required this.onSend,
    required this.onAttach,
    required this.onVoice,
    required this.onCancelVoice,
    required this.onPlayVoice,
    required this.onStartLiveVoice,
    required this.recordingVoice,
    required this.voiceElapsed,
    required this.onVerify,
    required this.onRename,
    required this.onGroupInfo,
    required this.onConnectionCheck,
    required this.onBack,
    required this.showSearch,
    required this.onToggleSearch,
    required this.onEmoji,
  });

  final ChatThread? thread;
  final List<ChatMessage> messages;
  final TextEditingController controller;
  final TextEditingController searchController;
  final Future<void> Function() onSend;
  final Future<void> Function() onAttach;
  final Future<void> Function() onVoice;
  final Future<void> Function() onCancelVoice;
  final Future<void> Function(ChatMessage) onPlayVoice;
  final Future<void> Function()? onStartLiveVoice;
  final bool recordingVoice;
  final Duration voiceElapsed;
  final VoidCallback? onVerify;
  final VoidCallback? onRename;
  final VoidCallback? onGroupInfo;
  final Future<void> Function()? onConnectionCheck;
  final VoidCallback? onBack;
  final bool showSearch;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onEmoji;

  @override
  Widget build(BuildContext context) {
    final selectedThread = thread;
    if (selectedThread == null) {
      return const _EmptyState(
        icon: Icons.forum_outlined,
        title: 'Nie wybrano rozmowy',
        message: 'Wybierz kontakt z listy albo znajdź osobę w pobliżu.',
      );
    }

    return SafeArea(
      child: Column(
        children: [
          _ChatHeader(
            thread: selectedThread,
            onRename: onRename,
            onVerify: onVerify,
            onGroupInfo: onGroupInfo,
            onConnectionCheck: onConnectionCheck,
            onStartLiveVoice: onStartLiveVoice,
            onBack: onBack,
            onToggleSearch: onToggleSearch,
          ),
          if (selectedThread.contact case final contact?
              when contact.publicKey == null)
            _ConnectionPendingBanner(),
          if (selectedThread.contact?.trustState == TrustState.keyChanged)
            _KeyChangedBanner(onVerify: onVerify),
          if (selectedThread.contact case final contact?
              when contact.publicKey != null &&
                  contact.trustState == TrustState.unverified)
            _UnverifiedContactBanner(onVerify: onVerify),
          const Divider(height: 1),
          if (showSearch)
            _ConversationSearchField(controller: searchController),
          Expanded(
            child: _MessageList(
              thread: selectedThread,
              messages: messages,
              onPlayVoice: onPlayVoice,
            ),
          ),
          _EmojiStrip(onEmoji: onEmoji),
          _MessageComposer(
            controller: controller,
            isGroup: selectedThread.isGroup,
            onAttach: onAttach,
            onVoice: onVoice,
            onCancelVoice: onCancelVoice,
            onSend: onSend,
            recordingVoice: recordingVoice,
            voiceElapsed: voiceElapsed,
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.thread,
    required this.onRename,
    required this.onVerify,
    required this.onGroupInfo,
    required this.onConnectionCheck,
    required this.onStartLiveVoice,
    required this.onBack,
    required this.onToggleSearch,
  });

  final ChatThread thread;
  final VoidCallback? onRename;
  final VoidCallback? onVerify;
  final VoidCallback? onGroupInfo;
  final Future<void> Function()? onConnectionCheck;
  final Future<void> Function()? onStartLiveVoice;
  final VoidCallback? onBack;
  final VoidCallback onToggleSearch;

  @override
  Widget build(BuildContext context) {
    final contact = thread.contact;
    final group = thread.group;
    final compact = MediaQuery.sizeOf(context).width < 390;
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 0 : 4, 6, 4, 6),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              tooltip: 'Wróć do rozmów',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
          _ThreadAvatar(thread: thread),
          SizedBox(width: compact ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  _subtitle(contact: contact, group: group),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (contact != null && !compact)
            IconButton(
              tooltip: contact.connected
                  ? 'Rozmowa głosowa'
                  : 'Kontakt jest poza zasięgiem',
              onPressed: contact.connected && contact.publicKey != null
                  ? onStartLiveVoice
                  : null,
              icon: const Icon(Icons.call_outlined),
            ),
          if (!compact)
            IconButton(
              tooltip: 'Szukaj w rozmowie',
              onPressed: onToggleSearch,
              icon: const Icon(Icons.search),
            ),
          PopupMenuButton<_ChatMenuAction>(
            tooltip: 'Więcej opcji',
            onSelected: (action) {
              switch (action) {
                case _ChatMenuAction.voice:
                  onStartLiveVoice?.call();
                  return;
                case _ChatMenuAction.search:
                  onToggleSearch();
                  return;
                case _ChatMenuAction.rename:
                  onRename?.call();
                  return;
                case _ChatMenuAction.verify:
                  onVerify?.call();
                  return;
                case _ChatMenuAction.groupInfo:
                  onGroupInfo?.call();
                  return;
                case _ChatMenuAction.connectionCheck:
                  onConnectionCheck?.call();
                  return;
              }
            },
            itemBuilder: (context) => [
              if (compact && contact != null)
                PopupMenuItem(
                  value: _ChatMenuAction.voice,
                  enabled: contact.connected && contact.publicKey != null,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.call_outlined),
                    title: const Text('Rozmowa głosowa'),
                    subtitle: contact.connected && contact.publicKey != null
                        ? null
                        : const Text('Kontakt poza zasięgiem'),
                  ),
                ),
              if (compact)
                const PopupMenuItem(
                  value: _ChatMenuAction.search,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.search),
                    title: Text('Szukaj w rozmowie'),
                  ),
                ),
              if (contact != null)
                PopupMenuItem(
                  value: _ChatMenuAction.connectionCheck,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      contact.connected
                          ? Icons.network_ping_outlined
                          : Icons
                                .signal_wifi_statusbar_connected_no_internet_4_outlined,
                    ),
                    title: const Text('Sprawdź połączenie'),
                  ),
                ),
              const PopupMenuItem(
                value: _ChatMenuAction.rename,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edytuj nazwę'),
                ),
              ),
              if (group != null)
                const PopupMenuItem(
                  value: _ChatMenuAction.groupInfo,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.group_outlined),
                    title: Text('Uczestnicy grupy'),
                  ),
                ),
              if (contact?.publicKey != null)
                PopupMenuItem(
                  value: _ChatMenuAction.verify,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      contact?.trustState == TrustState.verified
                          ? Icons.verified
                          : Icons.verified_outlined,
                    ),
                    title: const Text('Zweryfikuj kontakt'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _subtitle({required Contact? contact, required ChatGroup? group}) {
    if (group != null) {
      return '${group.memberIds.length} uczestników';
    }
    if (contact?.publicKey == null) {
      return 'Czeka na bezpieczne połączenie';
    }
    return '${contact!.trustLabel} • kod: ${contact.safetyCode}';
  }
}

enum _ChatMenuAction {
  voice,
  search,
  connectionCheck,
  rename,
  verify,
  groupInfo,
}

class _UnverifiedContactBanner extends StatelessWidget {
  const _UnverifiedContactBanner({required this.onVerify});

  final VoidCallback? onVerify;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      leading: const Icon(Icons.verified_user_outlined),
      content: const Text(
        'Potwierdź tożsamość tej osoby przed wysłaniem poufnych danych.',
      ),
      actions: [
        TextButton(onPressed: onVerify, child: const Text('Zweryfikuj')),
      ],
    );
  }
}

class _ConnectionPendingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: _FlowHint(
        icon: Icons.hourglass_top_outlined,
        title: 'Czekam na bezpieczne połączenie',
        body:
            'Zostaw oba telefony blisko siebie. Gdy połączenie będzie gotowe, wiadomości i pliki ruszą automatycznie.',
      ),
    );
  }
}

class _KeyChangedBanner extends StatelessWidget {
  const _KeyChangedBanner({required this.onVerify});

  final VoidCallback? onVerify;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      leading: const Icon(Icons.warning_amber),
      content: const Text(
        'Tożsamość tego kontaktu zmieniła się. Potwierdź osobę ponownie przed dalszą rozmową.',
      ),
      actions: [
        TextButton(onPressed: onVerify, child: const Text('Ufaj nowemu')),
      ],
    );
  }
}

class _ConversationSearchField extends StatelessWidget {
  const _ConversationSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          isDense: true,
          labelText: 'Szukaj w rozmowie',
          prefixIcon: Icon(Icons.search),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.thread,
    required this.messages,
    required this.onPlayVoice,
  });

  final ChatThread thread;
  final List<ChatMessage> messages;
  final Future<void> Function(ChatMessage) onPlayVoice;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    return ListView.builder(
      reverse: true,
      padding: EdgeInsets.all(compact ? 10 : 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - index - 1];
        return _MessageBubble(
          thread: thread,
          message: message,
          onPlayVoice: onPlayVoice,
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.thread,
    required this.message,
    required this.onPlayVoice,
  });

  final ChatThread thread;
  final ChatMessage message;
  final Future<void> Function(ChatMessage) onPlayVoice;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bubbleMaxWidth = screenWidth < 560 ? screenWidth - 56 : 520.0;
    return Align(
      alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: message.mine
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (thread.isGroup && !message.mine) ...[
                  Text(
                    message.senderName ?? 'Kontakt',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 2),
                ],
                Text(message.text),
                if (message.fileName != null)
                  _FileAttachmentSummary(message, onPlayVoice: onPlayVoice),
                const SizedBox(height: 4),
                Text(
                  _messageMeta,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _messageMeta => [
    _clock(message.sentAt),
    if (message.mine) message.status.label,
    if (thread.isGroup &&
        message.mine &&
        message.status == MessageStatus.sending &&
        message.progress != null)
      '${(message.progress! * 100).round()}%',
  ].join(' • ');
}

class _FileAttachmentSummary extends StatelessWidget {
  const _FileAttachmentSummary(this.message, {required this.onPlayVoice});

  final ChatMessage message;
  final Future<void> Function(ChatMessage) onPlayVoice;

  @override
  Widget build(BuildContext context) {
    if (message.isVoiceMessage) {
      return _VoiceAttachmentSummary(
        message: message,
        onPlay: () => onPlayVoice(message),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_file, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${message.fileName} • ${_formatBytes(message.fileSize ?? 0)}',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: message.progress),
      ],
    );
  }
}

class _VoiceAttachmentSummary extends StatelessWidget {
  const _VoiceAttachmentSummary({required this.message, required this.onPlay});

  final ChatMessage message;
  final Future<void> Function() onPlay;

  @override
  Widget build(BuildContext context) {
    final duration = Duration(milliseconds: message.voiceDurationMs ?? 0);
    final playable =
        message.status == MessageStatus.delivered &&
        message.filePath != null &&
        File(message.filePath!).existsSync();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              tooltip: 'Odtwórz wiadomość głosową',
              onPressed: playable ? onPlay : null,
              icon: const Icon(Icons.play_arrow),
            ),
            const SizedBox(width: 8),
            Text(
              '${_formatDuration(duration)} • ${_formatBytes(message.fileSize ?? 0)}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        if (message.status == MessageStatus.sending) ...[
          const SizedBox(height: 6),
          LinearProgressIndicator(value: message.progress),
        ],
      ],
    );
  }
}

class _EmojiStrip extends StatelessWidget {
  const _EmojiStrip({required this.onEmoji});

  final ValueChanged<String> onEmoji;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: _emojiChoices.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (_, index) => IconButton(
          tooltip: 'Emoji ${_emojiChoices[index]}',
          onPressed: () => onEmoji(_emojiChoices[index]),
          icon: Text(
            _emojiChoices[index],
            style: const TextStyle(fontSize: 22),
          ),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.isGroup,
    required this.onAttach,
    required this.onVoice,
    required this.onCancelVoice,
    required this.onSend,
    required this.recordingVoice,
    required this.voiceElapsed,
  });

  final TextEditingController controller;
  final bool isGroup;
  final Future<void> Function() onAttach;
  final Future<void> Function() onVoice;
  final Future<void> Function() onCancelVoice;
  final Future<void> Function() onSend;
  final bool recordingVoice;
  final Duration voiceElapsed;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final iconConstraints = compact
        ? const BoxConstraints.tightFor(width: 40, height: 40)
        : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 8 : 12, 0, compact ? 8 : 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (recordingVoice)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nagrywanie ${_formatDuration(voiceElapsed)} / 00:45',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Anuluj nagranie',
                    onPressed: onCancelVoice,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !recordingVoice,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Wiadomość...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              SizedBox(width: compact ? 4 : 8),
              IconButton(
                tooltip: 'Wyślij plik',
                onPressed: isGroup || recordingVoice ? null : onAttach,
                icon: const Icon(Icons.attach_file),
                constraints: iconConstraints,
                padding: EdgeInsets.all(compact ? 6 : 8),
              ),
              SizedBox(width: compact ? 2 : 4),
              IconButton(
                tooltip: recordingVoice
                    ? 'Zatrzymaj i wyślij'
                    : 'Nagraj wiadomość głosową',
                onPressed: isGroup ? null : onVoice,
                icon: Icon(recordingVoice ? Icons.stop : Icons.mic_none),
                constraints: iconConstraints,
                padding: EdgeInsets.all(compact ? 6 : 8),
              ),
              SizedBox(width: compact ? 2 : 4),
              IconButton.filled(
                tooltip: 'Wyślij',
                onPressed: recordingVoice ? null : onSend,
                icon: const Icon(Icons.send),
                constraints: iconConstraints,
                padding: EdgeInsets.all(compact ? 6 : 8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
