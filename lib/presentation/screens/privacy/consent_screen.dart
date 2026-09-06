import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/enums/consent_type.dart';
import 'package:k9sync/domain/interfaces/repositories/i_auth_repository.dart';
import 'package:k9sync/injection.dart';
import 'package:k9sync/presentation/router/route_guards.dart';

const _consentVersion = '1.0';

/// True if the user has already accepted the mandatory consent
/// (terms_of_service) — used to skip [ConsentScreen] on subsequent launches.
/// Any failure (network, logged out, etc.) is treated as "not consented yet"
/// so the screen is shown rather than silently letting the user through.
Future<bool> hasAcceptedRequiredConsent() async {
  try {
    final status = await getIt<IAuthRepository>().getConsentStatus();
    return status[ConsentType.termsOfService.value] == true;
  } catch (_) {
    return false;
  }
}

/// Premier lancement : CGU (obligatoires) + collecte GPS et santé
/// (optionnelles). Aucune case n'est cochée par défaut — un consentement
/// RGPD valide suppose un geste actif de l'utilisateur, jamais une case
/// pré-cochée.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, this.nextRoute});

  /// Route à rejoindre une fois les consentements enregistrés.
  /// Défaut : l'accueil (cas du lancement classique de l'app).
  final String? nextRoute;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _termsAccepted = false;
  bool _gpsAccepted = false;
  bool _healthAccepted = false;
  bool _submitting = false;

  Future<void> _submit() async {
    if (!_termsAccepted || _submitting) return;
    setState(() => _submitting = true);
    try {
      await getIt<IAuthRepository>().submitConsents([
        ConsentSubmission(
          type: ConsentType.termsOfService.value,
          accepted: _termsAccepted,
          version: _consentVersion,
        ),
        ConsentSubmission(
          type: ConsentType.gpsDataCollection.value,
          accepted: _gpsAccepted,
          version: _consentVersion,
        ),
        ConsentSubmission(
          type: ConsentType.healthDataCollection.value,
          accepted: _healthAccepted,
          version: _consentVersion,
        ),
      ]);
      if (!mounted) return;
      context.go(widget.nextRoute ?? AppRoutes.homeAccueil);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Échec de l\'enregistrement des consentements. Réessayez.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🐾', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 16),
                    const Text(
                      'Avant de commencer',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'K9 Sync a besoin de votre accord pour fonctionner. '
                      'Vous pourrez modifier ces choix à tout moment dans '
                      'Confidentialité.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _consentTile(
                      icon: '📄',
                      title: 'Conditions générales d\'utilisation',
                      description:
                          'Obligatoires pour utiliser K9 Sync.',
                      required: true,
                      value: _termsAccepted,
                      onChanged: (v) =>
                          setState(() => _termsAccepted = v ?? false),
                    ),
                    const SizedBox(height: 12),
                    _consentTile(
                      icon: '📍',
                      title: 'Collecte des données GPS',
                      description:
                          'Position du collier, historique des trajets. '
                          'Nécessaire pour le suivi en temps réel et le mode '
                          'chien perdu.',
                      required: false,
                      value: _gpsAccepted,
                      onChanged: (v) =>
                          setState(() => _gpsAccepted = v ?? false),
                    ),
                    const SizedBox(height: 12),
                    _consentTile(
                      icon: '💓',
                      title: 'Collecte des données de santé',
                      description:
                          'Fréquence cardiaque, température, activité. '
                          'Nécessaire pour la surveillance santé et la '
                          'détection d\'anomalies.',
                      required: false,
                      value: _healthAccepted,
                      onChanged: (v) =>
                          setState(() => _healthAccepted = v ?? false),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_termsAccepted && !_submitting) ? _submit : null,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Continuer'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _consentTile({
    required String icon,
    required String title,
    required String description,
    required bool required,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Material(
      color: AppColors.cardBg,
      borderRadius: AppDimensions.borderRadiusSm,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: AppDimensions.borderRadiusSm,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border, width: 1),
            borderRadius: AppDimensions.borderRadiusSm,
            boxShadow: [AppDimensions.cardShadowSm],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        if (required) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.orangeLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Requis',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.orange,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Checkbox(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
