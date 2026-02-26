import 'package:flutter/material.dart';

/// Écran édition profil chien (nom, poids, photo).
class DogEditScreen extends StatelessWidget {
  const DogEditScreen({super.key, this.dogId});
  final String? dogId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(dogId == null ? 'Nouveau chien' : 'Modifier le profil')),
      body: const Center(child: Text('Formulaire édition chien (squelette)')),
    );
  }
}
