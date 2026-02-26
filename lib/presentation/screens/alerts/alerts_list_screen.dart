import 'package:flutter/material.dart';

/// Liste des alertes (non lues en avant).
class AlertsListScreen extends StatelessWidget {
  const AlertsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alertes')),
      body: const Center(child: Text('Liste alertes (squelette)')),
    );
  }
}
