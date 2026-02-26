import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:k9sync/core/errors/auth_error.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/interfaces/repositories/i_auth_repository.dart';
import 'package:k9sync/injection.dart';
import 'package:k9sync/presentation/router/route_guards.dart';

/// Inscription en 3 étapes (mockup) : Identité, Profil chien, Consentements RGPD.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 0; // 0, 1, 2
  final _formKey = GlobalKey<FormState>();

  // Étape 1
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Étape 2
  final _dogNameController = TextEditingController();
  final _breedController = TextEditingController();
  final _birthController = TextEditingController();
  final _weightController = TextEditingController();

  // Étape 3
  bool _cguAccepted = false;
  bool _gpsAccepted = false;
  bool _communityAccepted = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _dogNameController.dispose();
    _breedController.dispose();
    _birthController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  double get _progress => (_step + 1) / 3;

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
              boxShadow: [
                BoxShadow(
                  color: AppColors.border,
                  offset: const Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barre de progression
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('🐾', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      'K9 Sync',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_step == 0) _buildStep1(),
                if (_step == 1) _buildStep2(),
                if (_step == 2) _buildStep3(),
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
        Text(
          'Créer un compte',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          'Étape 1 sur 3 — Vos informations',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        _label('Prénom'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _firstNameController,
          decoration: _decoration('Ex: Laurie'),
          validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
        ),
        const SizedBox(height: 14),
        _label('Nom'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _lastNameController,
          decoration: _decoration('Votre nom'),
          validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
        ),
        const SizedBox(height: 14),
        _label('Email'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: _decoration('votre@email.com'),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Requis';
            if (!v.contains('@')) return 'Email invalide';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _label('Mot de passe'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _passwordController,
          obscureText: true,
          decoration: _decoration('••••••••'),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Requis';
            if (v.length < 8) return 'Min. 8 caractères';
            return null;
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) setState(() => _step = 1);
          },
          child: const Text('Continuer →'),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => context.go(AppRoutes.signIn),
            child: Text(
              'Déjà un compte ? Se connecter',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Votre chien',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          'Étape 2 sur 3 — Profil de votre compagnon',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cream,
                  border: Border.all(color: AppColors.border, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.border,
                      offset: const Offset(3, 3),
                      blurRadius: 0,
                    ),
                ],
                ),
                child: const Center(child: Text('🐕', style: TextStyle(fontSize: 44))),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    border: Border.all(color: AppColors.border, width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _label('Nom du chien'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _dogNameController,
          decoration: _decoration('Ex: Bucky'),
          validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
        ),
        const SizedBox(height: 14),
        _label('Race'),
        const SizedBox(height: 4),
        TextFormField(
          controller: _breedController,
          decoration: _decoration('Ex: Beagle'),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Naissance'),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _birthController,
                    decoration: _decoration('JJ/MM/AAAA'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Poids (kg)'),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: _decoration('Ex: 12.4'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) setState(() => _step = 2);
                },
                child: const Text('Continuer →'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 0),
                child: const Text('← Retour'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Confidentialité',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          'Étape 3 sur 3 — Vos consentements',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.blueLight,
            border: Border.all(color: AppColors.border, width: 2),
            borderRadius: AppDimensions.borderRadiusSm,
          ),
          child: Text(
            'ℹ️ À savoir : Les données GPS de votre chien permettent de localiser indirectement vos propres déplacements. En savoir plus',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _consentTile(
          value: _cguAccepted,
          onChanged: (v) => setState(() => _cguAccepted = v!),
          title: 'J\'accepte les CGU et la Politique de confidentialité *',
          required: true,
        ),
        const SizedBox(height: 8),
        _consentTile(
          value: _gpsAccepted,
          onChanged: (v) => setState(() => _gpsAccepted = v!),
          title: 'Collecte données GPS et santé (nécessaire au service) *',
          required: true,
        ),
        const SizedBox(height: 8),
        _consentTile(
          value: _communityAccepted,
          onChanged: (v) => setState(() => _communityAccepted = v!),
          title: 'Fonctionnalités communautaires',
          required: false,
          optional: true,
        ),
        const SizedBox(height: 8),
        Text(
          '* Champs obligatoires pour utiliser K9 Sync',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitRegister,
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Créer mon compte 🐾'),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() => _step = 1),
            child: const Text('← Retour'),
          ),
        ),
      ],
    );
  }

  Future<void> _submitRegister() async {
    if (!_cguAccepted || !_gpsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez accepter les champs obligatoires.'),
        ),
      );
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (email.isEmpty || password.isEmpty || firstName.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs de l\'étape Identité.')),
      );
      return;
    }
    if (!getIt.isRegistered<IAuthRepository>()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service non prêt. Fermez l\'app et relancez-la (pas de hot reload).'),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await getIt<IAuthRepository>().register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      if (!mounted) return;
      context.go(AppRoutes.homeAccueil);
    } on AuthError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.userMessage ?? e.message)),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final authErr = AuthError.fromDio(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authErr.userMessage ?? 'Erreur d\'inscription.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _consentTile({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String title,
    required bool required,
    bool optional = false,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: AppDimensions.borderRadiusSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  borderRadius: BorderRadius.circular(6),
                ),
                side: BorderSide(
                  color: value ? AppColors.orange : Colors.grey,
                  width: 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
            if (optional)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.yellowLight,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'optionnel',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: AppColors.textMuted,
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey.shade400,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }
}
