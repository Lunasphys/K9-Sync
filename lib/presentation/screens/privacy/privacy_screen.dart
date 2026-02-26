import 'package:flutter/material.dart';

/// RGPD: consentements, export données, suppression compte.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confidentialité & Données')),
      body: const Center(child: Text('RGPD: consentements, export, suppression (squelette)')),
    );
  }
}
