import 'package:flutter/material.dart';

/// Carte GPS (flutter_map) — squelette.
class GpsMapWidget extends StatelessWidget {
  const GpsMapWidget({
    super.key,
    this.initialCenter,
    this.initialZoom = 15,
    this.markers = const [],
  });

  final dynamic initialCenter;
  final double initialZoom;
  final List<Widget> markers;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map, size: 64),
            const SizedBox(height: 8),
            Text('Carte (flutter_map)', style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
