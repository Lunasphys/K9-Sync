import 'package:flutter/material.dart';

/// Premier lancement: CGU + politique confidentialité + consentements.
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consentements')),
      body: const Center(child: Text('CGU + Politique confidentialité (squelette)')),
    );
  }
}
