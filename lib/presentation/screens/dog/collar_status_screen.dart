import 'package:flutter/material.dart';

/// Statut collier: batterie, connexion, firmware.
class CollarStatusScreen extends StatelessWidget {
  const CollarStatusScreen({super.key, this.collarId});
  final String? collarId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collier')),
      body: Center(child: Text('Statut collier ${collarId ?? "?"} (squelette)')),
    );
  }
}
