import 'package:flutter/material.dart';

/// Historique des parcours.
class TrailHistoryScreen extends StatelessWidget {
  const TrailHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des parcours')),
      body: const Center(child: Text('Liste parcours (squelette)')),
    );
  }
}
