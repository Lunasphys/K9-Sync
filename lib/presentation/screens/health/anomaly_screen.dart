import 'package:flutter/material.dart';

/// Anomalies détectées.
class AnomalyScreen extends StatelessWidget {
  const AnomalyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anomalies')),
      body: const Center(child: Text('Anomalies (squelette)')),
    );
  }
}
