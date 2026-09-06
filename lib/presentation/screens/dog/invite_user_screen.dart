import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:k9sync/core/errors/app_error.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/enums/user_dog_role.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';
import 'package:k9sync/injection.dart';

const _months = [
  'jan.',
  'fév.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Inviter quelqu'un à partager l'accès à un chien.
/// Appelle POST /dogs/:dogId/invite — l'accès est soit accordé
/// immédiatement (email déjà inscrit), soit mis en attente (email inconnu,
/// résolu automatiquement à l'inscription).
class InviteUserScreen extends StatefulWidget {
  const InviteUserScreen({super.key, this.dogId, this.dogName});
  final String? dogId;
  final String? dogName;

  @override
  State<InviteUserScreen> createState() => _InviteUserScreenState();
}

class _InviteUserScreenState extends State<InviteUserScreen> {
  final _emailController = TextEditingController();
  bool _roleDogSitter = true; // true = Dog-sitter, false = Famille
  DateTime? _expiresAt;
  bool _showConfirmModal = false;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _emailValid => _emailRegex.hasMatch(_emailController.text.trim());
  bool get _canContinue =>
      _emailValid &&
      (!_roleDogSitter || _expiresAt != null) &&
      widget.dogId != null;

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _confirmAndSend() async {
    final dogId = widget.dogId;
    if (dogId == null || _submitting) return;

    setState(() {
      _showConfirmModal = false;
      _submitting = true;
    });

    final email = _emailController.text.trim();
    try {
      final outcome = await getIt<IDogRepository>().inviteUser(
        dogId,
        email: email,
        role: _roleDogSitter ? UserDogRole.dogSitter : UserDogRole.family,
        expiresAt: _roleDogSitter ? _expiresAt : null,
      );
      if (!mounted) return;
      await _showOutcomeDialog(outcome, email);
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final message = e is AppError
          ? (e.userMessage ?? 'Échec de l\'invitation.')
          : 'Échec de l\'invitation.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _showOutcomeDialog(InviteOutcome outcome, String email) {
    final granted = outcome == InviteOutcome.granted;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(granted ? 'Accès accordé ✅' : 'Invitation enregistrée 📩'),
        content: Text(
          granted
              ? '$email a déjà un compte K9 Sync : l\'accès a été accordé immédiatement.'
              : '$email n\'a pas encore de compte K9 Sync. L\'accès sera accordé '
                    'automatiquement dès qu\'iel en créera un avec cette adresse exacte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: 'Retour',
          child: IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 18,
                color: AppColors.textMuted,
              ),
            ),
            onPressed: () => context.pop(),
          ),
        ),
        title: const Text(
          'Inviter',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border, width: 1),
                      borderRadius: AppDimensions.borderRadiusSm,
                      boxShadow: [AppDimensions.cardShadowSm],
                    ),
                    child: Row(
                      children: [
                        const Text('🐕', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'Accès au chien ',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                              children: [
                                TextSpan(
                                  text: widget.dogName ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _inputLabel('ADRESSE EMAIL'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Semantics(
                    textField: true,
                    label: 'Adresse email de la personne à inviter',
                    hint: _emailController.text.isEmpty
                        ? null
                        : (_emailValid ? 'Adresse valide' : 'Adresse invalide'),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'julie.m@gmail.com',
                        filled: true,
                        fillColor: AppColors.surface,
                        suffixIcon: _emailController.text.isEmpty
                            ? null
                            : Icon(
                                _emailValid ? Icons.check : Icons.close,
                                color: _emailValid
                                    ? AppColors.greenStatus
                                    : AppColors.redDanger,
                              ),
                        border: OutlineInputBorder(
                          borderRadius: AppDimensions.borderRadiusSm,
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _inputLabel('RÔLE'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _roleOpt(
                          icon: '👨‍👩‍👧',
                          name: 'Famille',
                          sub: 'Permanent',
                          selected: !_roleDogSitter,
                          onTap: () => setState(() => _roleDogSitter = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _roleOpt(
                          icon: '🐾',
                          name: 'Dog-sitter',
                          sub: 'Temporaire',
                          selected: _roleDogSitter,
                          onTap: () => setState(() => _roleDogSitter = true),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_roleDogSitter) ...[
                  const SizedBox(height: 14),
                  _inputLabel('DATE DE FIN D\'ACCÈS'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Semantics(
                      button: true,
                      label: _expiresAt != null
                          ? 'Date de fin d\'accès : ${_formatDate(_expiresAt!)}. '
                                'Modifier'
                          : 'Sélectionner une date de fin d\'accès',
                      child: InkWell(
                        onTap: _pickExpiryDate,
                        borderRadius: AppDimensions.borderRadiusSm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: _expiresAt != null
                                ? AppColors.cardBg
                                : AppColors.surface,
                            border: Border.all(
                              color: _expiresAt != null
                                  ? AppColors.blue
                                  : AppColors.border,
                              width: 1.5,
                            ),
                            borderRadius: AppDimensions.borderRadiusSm,
                            boxShadow: [AppDimensions.cardShadowSm],
                          ),
                          child: Row(
                            children: [
                              Text(
                                _expiresAt != null
                                    ? _formatDate(_expiresAt!)
                                    : 'Sélectionner une date',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _expiresAt != null
                                      ? AppColors.text
                                      : AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    'CE QUE CETTE PERSONNE POURRA FAIRE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                _permPreviewList(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    'Indicatif : K9 Sync ne contrôle pas encore chaque action '
                    'individuellement, seulement l\'accès global au chien.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Semantics(
                    button: true,
                    enabled: _canContinue,
                    label: _canContinue
                        ? 'Continuer vers la confirmation de l\'invitation'
                        : 'Continuer — indisponible tant que l\'adresse '
                              'email et les informations requises ne sont '
                              'pas renseignées',
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canContinue
                            ? () => setState(() => _showConfirmModal = true)
                            : null,
                        child: const Text('Continuer →'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showConfirmModal)
            _ConfirmRgpdModal(
              email: _emailController.text.trim(),
              roleLabel: _roleDogSitter ? 'Dog-sitter' : 'Famille',
              expiresAt: _roleDogSitter ? _expiresAt : null,
              submitting: _submitting,
              onConfirm: _confirmAndSend,
              onCancel: () => setState(() => _showConfirmModal = false),
            ),
        ],
      ),
    );
  }

  Widget _inputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _roleOpt({
    required String icon,
    required String name,
    required String sub,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Rôle $name, $sub',
      child: MergeSemantics(
        child: Material(
          color: selected ? AppColors.blueLight : AppColors.surface,
          borderRadius: AppDimensions.borderRadiusSm,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppDimensions.borderRadiusSm,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? AppColors.blue : AppColors.border,
                  width: selected ? 2 : 1,
                ),
                borderRadius: AppDimensions.borderRadiusSm,
                boxShadow: [AppDimensions.cardShadowSm],
              ),
              child: Column(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 10,
                      color: selected ? AppColors.blue : AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _permPreviewList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.border, width: 1),
          borderRadius: AppDimensions.borderRadiusSm,
          boxShadow: [AppDimensions.cardShadowSm],
        ),
        child: Column(
          children: [
            _permRow('Voir la position GPS', true),
            _permRow('Recevoir les alertes en temps réel', true),
            _permRow('Voir les données de santé', true),
            _permRow('Modifier le profil ou les zones', false),
          ],
        ),
      ),
    );
  }

  Widget _permRow(String label, bool allowed) {
    return Semantics(
      label: '$label : ${allowed ? "autorisé" : "non autorisé"}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(
              allowed ? Icons.check : Icons.close,
              size: 14,
              color: allowed ? AppColors.greenStatus : AppColors.redDanger,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: allowed ? AppColors.text : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmRgpdModal extends StatelessWidget {
  final String email;
  final String roleLabel;
  final DateTime? expiresAt;
  final bool submitting;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ConfirmRgpdModal({
    required this.email,
    required this.roleLabel,
    required this.expiresAt,
    required this.submitting,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: GestureDetector(
                  onTap: submitting ? null : onCancel,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).padding.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Avant de confirmer 🔒',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      text: 'En invitant ',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(
                          text: email,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        TextSpan(text: ' comme $roleLabel :'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.orangeLight,
                      border: Border.all(
                        color: AppColors.orange.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('⚠️', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cette personne verra la position de votre chien et '
                            'pourra en déduire vos habitudes et horaires.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.orange,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border, width: 1),
                      borderRadius: AppDimensions.borderRadiusSm,
                    ),
                    child: Column(
                      children: [
                        _confirmRow('Email', email),
                        _confirmRow('Rôle', roleLabel),
                        if (expiresAt != null)
                          _confirmRow('Accès expire', _formatDate(expiresAt!)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    button: true,
                    enabled: !submitting,
                    label: submitting
                        ? 'Envoi de l\'invitation en cours'
                        : 'Confirmer l\'invitation de $email en tant que '
                              '$roleLabel, avec accès à la position GPS et '
                              'aux données de santé du chien',
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: submitting ? null : onConfirm,
                        child: submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('✓ Confirmer l\'invitation'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: submitting ? null : onCancel,
                      child: const Text('Annuler'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _confirmRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
