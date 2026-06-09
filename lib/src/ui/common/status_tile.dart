part of '../../../main.dart';

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.good,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final color = good
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(value),
      trailing: Icon(
        good ? Icons.check_circle_outline : Icons.error_outline,
        color: color,
      ),
    );
  }
}
