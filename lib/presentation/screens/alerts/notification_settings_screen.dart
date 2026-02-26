import 'package:flutter/material.dart';

/// Réglages notifications push par type.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const Center(child: Text('Réglages notifications (squelette)')),
    );
  }
}
