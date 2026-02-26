import 'package:flutter/material.dart';

/// Accès partagés — famille, dog-sitter (liste + invitation).
class SharedAccessScreen extends StatelessWidget {
  const SharedAccessScreen({super.key, this.dogId});
  final String? dogId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accès partagés')),
      body: Center(child: Text('Liste des accès ${dogId ?? ""} (squelette)')),
    );
  }
}
