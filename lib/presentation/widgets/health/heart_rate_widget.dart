import 'package:flutter/material.dart';

/// Widget affichant la FC (bpm) avec indicateur visuel.
class HeartRateWidget extends StatelessWidget {
  const HeartRateWidget({super.key, this.bpm, this.label = 'FC'});
  final int? bpm;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.favorite, color: Colors.red.shade400, size: 28),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text('${bpm ?? '--'} bpm', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ],
    );
  }
}
