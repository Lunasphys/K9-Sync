import 'package:flutter/material.dart';

/// Activité: pas, temps actif/repos.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activité')),
      body: const Center(child: Text('Activité (squelette)')),
    );
  }
}
