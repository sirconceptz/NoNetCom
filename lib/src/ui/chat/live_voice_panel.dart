part of '../../../main.dart';

class _LiveVoicePanel extends StatelessWidget {
  const _LiveVoicePanel({
    required this.session,
    required this.elapsed,
    required this.quality,
    required this.speaking,
    required this.onAccept,
    required this.onReject,
    required this.onToggleSpeaking,
    required this.onEnd,
  });

  final LiveVoiceSession session;
  final Duration elapsed;
  final LiveVoiceQuality quality;
  final bool speaking;
  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;
  final Future<void> Function() onToggleSpeaking;
  final Future<void> Function() onEnd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Material(
              elevation: 8,
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: const Icon(Icons.graphic_eq),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.peerName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(_statusLabel),
                            ],
                          ),
                        ),
                        if (session.state == LiveVoiceState.connected)
                          _QualityIndicator(quality: quality),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (session.state == LiveVoiceState.incoming)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onReject,
                              icon: const Icon(Icons.call_end),
                              label: const Text('Odrzuć'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: onAccept,
                              icon: const Icon(Icons.call),
                              label: const Text('Odbierz'),
                            ),
                          ),
                        ],
                      )
                    else if (session.state == LiveVoiceState.calling)
                      OutlinedButton.icon(
                        onPressed: onEnd,
                        icon: const Icon(Icons.call_end),
                        label: const Text('Anuluj'),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: onToggleSpeaking,
                              style: FilledButton.styleFrom(
                                backgroundColor: speaking
                                    ? colorScheme.tertiary
                                    : null,
                              ),
                              icon: Icon(speaking ? Icons.stop : Icons.mic),
                              label: Text(
                                speaking
                                    ? 'Zatrzymaj mówienie'
                                    : 'Zacznij mówić',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filled(
                            tooltip: 'Zakończ rozmowę',
                            onPressed: onEnd,
                            style: IconButton.styleFrom(
                              backgroundColor: colorScheme.error,
                              foregroundColor: colorScheme.onError,
                            ),
                            icon: const Icon(Icons.call_end),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _statusLabel => switch (session.state) {
    LiveVoiceState.calling => 'Łączenie...',
    LiveVoiceState.incoming => 'Przychodząca rozmowa głosowa',
    LiveVoiceState.connected =>
      '${_formatDuration(elapsed)} • szyfrowanie end-to-end',
  };
}

class _QualityIndicator extends StatelessWidget {
  const _QualityIndicator({required this.quality});

  final LiveVoiceQuality quality;

  @override
  Widget build(BuildContext context) {
    final color = switch (quality) {
      LiveVoiceQuality.good => Colors.green,
      LiveVoiceQuality.fair => Colors.orange,
      LiveVoiceQuality.weak => Theme.of(context).colorScheme.error,
    };
    return Tooltip(
      message: 'Jakość połączenia: ${quality.label}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.network_cell, color: color, size: 18),
          const SizedBox(width: 4),
          Text(quality.label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
