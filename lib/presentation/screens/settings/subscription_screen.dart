import 'package:flutter/material.dart';

/// Abonnement Free / Premium.
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abonnement')),
      body: const Center(child: Text('Abonnement (squelette)')),
    );
  }
}
