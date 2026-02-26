import 'package:flutter/material.dart';

/// Carte GPS temps réel (flutter_map).
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carte')),
      body: const Center(child: Text('Carte temps réel (squelette)')),
    );
  }
}
