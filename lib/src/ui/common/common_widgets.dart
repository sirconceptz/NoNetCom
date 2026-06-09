part of '../../../main.dart';

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
            ],
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ThreadAvatar extends StatelessWidget {
  const _ThreadAvatar({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      child: thread.isGroup
          ? const Icon(Icons.groups_2_outlined)
          : Text(thread.initials),
    );
  }
}

class _AppSectionAction extends StatelessWidget {
  const _AppSectionAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _CapabilityStatusRow extends StatelessWidget {
  const _CapabilityStatusRow({
    required this.item,
    required this.onRequest,
    required this.onSettings,
  });

  final CapabilityStatusItem item;
  final VoidCallback? onRequest;
  final Future<bool> Function() onSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = item.good ? Icons.check_circle_outline : Icons.error_outline;
    final iconColor = item.good ? Colors.green : scheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('${item.status}. ${item.fix}'),
                    if (!item.good) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: onRequest,
                            icon: const Icon(Icons.verified_user_outlined),
                            label: const Text('Poproś ponownie'),
                          ),
                          OutlinedButton.icon(
                            onPressed: onSettings,
                            icon: const Icon(Icons.tune_outlined),
                            label: const Text('Ustawienia'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
