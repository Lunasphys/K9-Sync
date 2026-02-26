import 'package:flutter/material.dart';

/// Profil d'un chien (race, âge, poids, etc.).
class DogProfileScreen extends StatelessWidget {
  const DogProfileScreen({super.key, this.dogId});
  final String? dogId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil chien')),
      body: Center(child: Text('Profil chien ${dogId ?? "?"} (squelette)')),
    );
  }
}
