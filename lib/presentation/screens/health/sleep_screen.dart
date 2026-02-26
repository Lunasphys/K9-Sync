import 'package:flutter/material.dart';

/// Phases sommeil.
class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sommeil')),
      body: const Center(child: Text('Analyse sommeil (squelette)')),
    );
  }
}
