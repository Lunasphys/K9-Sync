import 'package:flutter/material.dart';

/// Carte affichant une métrique santé (titre + valeur + unité).
class HealthCard extends StatelessWidget {
  const HealthCard({
    super.key,
    required this.title,
    required this.value,
    this.unit,
    this.icon,
  });

  final String title;
  final String value;
  final String? unit;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) Icon(icon, size: 20),
                if (icon != null) const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            if (unit != null) Text(unit!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
