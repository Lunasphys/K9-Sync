import 'package:flutter/material.dart';

/// Forgot password: send reset email.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: const Center(child: Text('Squelette récupération mot de passe')),
    );
  }
}
