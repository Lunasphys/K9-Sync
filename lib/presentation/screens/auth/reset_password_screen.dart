import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:k9sync/core/errors/auth_error.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/interfaces/repositories/i_auth_repository.dart';
import 'package:k9sync/injection.dart';
import 'package:k9sync/presentation/router/route_guards.dart';

/// Réinitialisation du mot de passe : code à 6 chiffres reçu par email +
/// nouveau mot de passe. Appelle IAuthRepository.resetPassword(). Le succès
/// invalide toutes les sessions côté serveur — on redirige donc vers /login
/// (pas de connexion automatique), jamais dans l'app.
///
/// [email] est pré-rempli quand l'écran est atteint depuis
/// [ForgotPasswordScreen] (via `extra`), mais reste éditable : un accès
/// direct à cet écran (ex. état perdu au hot-reload) ne doit pas bloquer
/// l'utilisateur qui a déjà son code en main.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.email});
  final String? email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: widget.email);
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await getIt<IAuthRepository>().resetPassword(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mot de passe réinitialisé. Connectez-vous avec votre nouveau mot de passe.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      context.go(AppRoutes.login);
    } on AuthError catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage = e.userMessage ?? 'Erreur d\'authentification.',
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final authErr = AuthError.fromDio(e);
      setState(
        () => _errorMessage =
            authErr.userMessage ?? 'Impossible de réinitialiser le mot de passe.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'Impossible de réinitialiser le mot de passe. Vérifiez votre connexion.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          onPressed: _isLoading ? null : () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Réinitialiser le mot de passe',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Saisissez le code à 6 chiffres reçu par email et votre nouveau mot de passe.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  _ErrorBanner(message: _errorMessage!),
                  const SizedBox(height: 16),
                ],
                _buildLabel('Email'),
                const SizedBox(height: 4),
                Semantics(
                  textField: true,
                  label: 'Adresse email',
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                    decoration: _inputDecoration(hint: 'votre@email.com'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Champ requis';
                      if (!v.contains('@')) return 'Email invalide';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabel('Code à 6 chiffres'),
                const SizedBox(height: 4),
                Semantics(
                  textField: true,
                  label: 'Code de réinitialisation à 6 chiffres',
                  child: TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    enabled: !_isLoading,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: _inputDecoration(hint: '123456').copyWith(
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Champ requis';
                      if (v.length != 6) return 'Le code doit contenir 6 chiffres';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabel('Nouveau mot de passe'),
                const SizedBox(height: 4),
                Semantics(
                  textField: true,
                  label: 'Nouveau mot de passe',
                  child: TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    enabled: !_isLoading,
                    decoration: _inputDecoration(hint: '••••••••').copyWith(
                      suffixIcon: Semantics(
                        button: true,
                        label: _obscureNewPassword
                            ? 'Afficher le mot de passe'
                            : 'Masquer le mot de passe',
                        child: IconButton(
                          icon: Icon(
                            _obscureNewPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(
                            () => _obscureNewPassword = !_obscureNewPassword,
                          ),
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Champ requis';
                      if (v.length < 8) return 'Minimum 8 caractères';
                      final hasUpper = v.contains(RegExp(r'[A-Z]'));
                      final hasDigit = v.contains(RegExp(r'[0-9]'));
                      if (!hasUpper || !hasDigit) {
                        return '1 majuscule et 1 chiffre requis';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabel('Confirmer le mot de passe'),
                const SizedBox(height: 4),
                Semantics(
                  textField: true,
                  label: 'Confirmation du nouveau mot de passe',
                  child: TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    enabled: !_isLoading,
                    decoration: _inputDecoration(hint: '••••••••').copyWith(
                      suffixIcon: Semantics(
                        button: true,
                        label: _obscureConfirmPassword
                            ? 'Afficher le mot de passe'
                            : 'Masquer le mot de passe',
                        child: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Champ requis';
                      if (v != _newPasswordController.text) {
                        return 'Les mots de passe ne correspondent pas';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 28),
                Semantics(
                  button: true,
                  enabled: !_isLoading,
                  label: _isLoading
                      ? 'Réinitialisation en cours'
                      : 'Réinitialiser le mot de passe',
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Réinitialiser'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Semantics(
                    button: true,
                    label: 'Retour',
                    child: TextButton(
                      onPressed: _isLoading ? null : () => context.pop(),
                      child: Text(
                        'Retour',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
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

  InputDecoration _inputDecoration({required String hint}) {
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.redLight,
        border: Border.all(color: AppColors.redDanger, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE84040),
            offset: Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.redDanger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.redDanger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
