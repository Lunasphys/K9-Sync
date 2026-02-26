import 'package:flutter/material.dart';

/// Liste des chiens de l'utilisateur.
class DogListScreen extends StatelessWidget {
  const DogListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes chiens')),
      body: const Center(child: Text('Liste chiens (squelette)')),
    );
  }
}
