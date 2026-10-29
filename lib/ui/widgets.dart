import 'package:flutter/material.dart';

import '../data/models/person.dart';
import 'ui_helpers.dart';

/// صورة رمزية حسب الجنس (بلا صور شخصية في هذه النسخة).
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.gender, this.radius = 20});

  final Gender gender;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (gender) {
      Gender.male => (Colors.blue.shade100, Colors.blue.shade800),
      Gender.female => (Colors.pink.shade100, Colors.pink.shade800),
      Gender.unknown => (Colors.blueGrey.shade100, Colors.blueGrey.shade700),
    };
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      foregroundColor: fg,
      child: Icon(genderIcon(gender), size: radius * 1.15),
    );
  }
}

/// بطاقة قسم: أيقونة في دائرة زرقاء فاتحة، عنوان أزرق غامق، وخط رفيع (كبطاقة الفرد).
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: scheme.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Divider(height: 1, color: scheme.outlineVariant),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
