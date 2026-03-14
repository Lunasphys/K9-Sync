import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:k9sync/core/errors/auth_error.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/interfaces/repositories/i_auth_repository.dart';
import 'package:k9sync/injection.dart';
import 'package:k9sync/presentation/router/route_guards.dart';

/// Registration — 2 steps: identity then RGPD consents.
/// Dog profile is created separately in DogSetupScreen.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 0; // 0 = identity, 1 = consents
  final _formKey = GlobalKey<FormState>();

  // Step 1
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  // Step 2
  bool _cguAccepted = false;
  bool _gpsAccepted = false;
  bool _communityAccepted = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  double get _progress => (_step + 1) / 2;

  Future<void> _submit() async {
    if (!_cguAccepted || !_gpsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez accepter les champs obligatoires.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await getIt<IAuthRepository>().register(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
      );
      if (!mounted) return;
      context.go(AppRoutes.dogSetup);
    } on AuthError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.userMessage ?? e.message)),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final err = AuthError.fromDio(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.userMessage ?? 'Erreur d\'inscription.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border.all(color: AppColors.border, width: 2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, size: 20),
          ),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step--);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.orange),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  const Text('🐾', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  const Text('K9 Sync',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 16),
                if (_step == 0) _buildStep1(),
                if (_step == 1) _buildStep2(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Créer un compte',
            style:
                TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Étape 1 sur 2 — Vos informations',
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),

        _label('Prénom'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _firstNameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: _inputDeco('Ex : Laurie'),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Requis' : null,
        ),
        const SizedBox(height: 14),

        _label('Nom'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _lastNameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: _inputDeco('Votre nom'),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Requis' : null,
        ),
        const SizedBox(height: 14),

        _label('Email'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDeco('votre@email.com'),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Requis';
            if (!v.contains('@') || !v.contains('.')) {
              return 'Email invalide';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),

        _label('Mot de passe'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          decoration: _inputDeco('••••••••').copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Requis';
            if (v.length < 8) return 'Minimum 8 caractères';
            final hasUpper = v.contains(RegExp(r'[A-Z]'));
            final hasDigit = v.contains(RegExp(r'[0-9]'));
            if (!hasUpper || !hasDigit) {
              return '1 majuscule et 1 chiffre requis';
            }
            return null;
          },
        ),
        const SizedBox(height: 28),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
              side: BorderSide(color: AppColors.border, width: 2),
            ),
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              setState(() => _step = 1);
            }
          },
          child: const Text('Continuer →',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => context.go(AppRoutes.signIn),
            child: Text('Déjà un compte ? Se connecter',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Confidentialité',
            style:
                TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Étape 2 sur 2 — Vos consentements',
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.blueLight,
            border: Border.all(color: AppColors.border, width: 2),
            borderRadius: AppDimensions.borderRadiusSm,
          ),
          child: const Text(
            'ℹ️ Les données GPS de votre chien peuvent permettre de localiser indirectement vos déplacements.',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.5),
          ),
        ),
        const SizedBox(height: 16),

        _consentTile(
          value: _cguAccepted,
          onChanged: (v) => setState(() => _cguAccepted = v!),
          title:
              'J\'accepte les CGU et la Politique de confidentialité *',
        ),
        const SizedBox(height: 8),
        _consentTile(
          value: _gpsAccepted,
          onChanged: (v) => setState(() => _gpsAccepted = v!),
          title:
              'Collecte données GPS et santé (nécessaire au service) *',
        ),
        const SizedBox(height: 8),
        _consentTile(
          value: _communityAccepted,
          onChanged: (v) => setState(() => _communityAccepted = v!),
          title: 'Fonctionnalités communautaires (optionnel)',
          optional: true,
        ),
        const SizedBox(height: 8),
        Text('* Champs obligatoires',
            style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 28),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
              side: BorderSide(color: AppColors.border, width: 2),
            ),
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(strokeWidth: 2))
              : const Text('Créer mon compte 🐾',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => setState(() => _step = 0),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: AppColors.border, width: 2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50)),
          ),
          child: const Text('← Retour',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _consentTile({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String title,
    bool optional = false,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: AppDimensions.borderRadiusSm,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.border, width: 2),
          borderRadius: AppDimensions.borderRadiusSm,
          boxShadow: [AppDimensions.cardShadowSm],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.orange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                side: BorderSide(
                    color: value ? AppColors.orange : Colors.grey,
                    width: 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.4)),
            ),
            if (optional)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.yellowLight,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('optionnel',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.textMuted),
        ),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w600,
            fontSize: 14),
        filled: true,
        fillColor: AppColors.cardBg,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusSm,
          borderSide: BorderSide(color: AppColors.border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusSm,
          borderSide: BorderSide(color: AppColors.border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusSm,
          borderSide: BorderSide(color: AppColors.orange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusSm,
          borderSide:
              const BorderSide(color: Colors.red, width: 2),
        ),
      );
}
