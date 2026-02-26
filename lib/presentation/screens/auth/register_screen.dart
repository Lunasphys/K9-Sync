import 'package:flutter/material.dart';

/// Register: email, password, firstName, lastName.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: const Center(child: Text('Formulaire inscription (squelette)')),
    );
  }
}
