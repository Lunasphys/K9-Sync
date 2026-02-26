import 'package:flutter/material.dart';

/// Login: email + password.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text('Email + Mot de passe (form à brancher)'),
          ],
        ),
      ),
    );
  }
}
