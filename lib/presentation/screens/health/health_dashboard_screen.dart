import 'package:flutter/material.dart';

/// Dashboard santé: FC, température, activité du jour.
class HealthDashboardScreen extends StatelessWidget {
  const HealthDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Santé')),
      body: const Center(child: Text('Dashboard santé (squelette)')),
    );
  }
}
