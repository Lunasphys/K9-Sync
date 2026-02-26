import 'package:flutter/material.dart';

/// Mode chien perdu: activer signal sonore/lumineux.
class LostModeScreen extends StatelessWidget {
  const LostModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chien perdu')),
      body: const Center(child: Text('Activer/désactiver mode perdu (squelette)')),
    );
  }
}
