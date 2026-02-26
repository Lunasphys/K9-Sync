import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:k9sync/core/theme/app_theme.dart';

/// Inviter (mockup light) : formulaire email + rôle + date fin, modal confirmation RGPD.
class InviteUserScreen extends StatefulWidget {
  const InviteUserScreen({super.key, this.dogId});
  final String? dogId;

  @override
  State<InviteUserScreen> createState() => _InviteUserScreenState();
}

class _InviteUserScreenState extends State<InviteUserScreen> {
  bool _roleDogSitter = true; // true = Dog-sitter, false = Famille
  bool _showConfirmModal = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border, width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, size: 18, color: AppColors.textMuted),
          ),
          onPressed: () => context.pop(),
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border, width: 1),
                      borderRadius: AppDimensions.borderRadiusSm,
                      boxShadow: [AppDimensions.cardShadowSm],
                    ),
                    child: const Row(
                      children: [
                        Text('🐕', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'Accès au collier de ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Bucky',
                                  style: TextStyle(fontWeight: FontWeight.w800),
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
                _inputField('julie.m@gmail.com', valid: true),
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
                const SizedBox(height: 14),
                _inputLabel('DATE DE FIN D\'ACCÈS'),
                _inputField('30 janvier 2026', valid: false),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    'CE QUE JULIE POURRA FAIRE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                _permPreviewList(),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _showConfirmModal = true),
                      child: const Text('Continuer →'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showConfirmModal) _ConfirmRgpdModal(
            onConfirm: () {
              setState(() => _showConfirmModal = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invitation envoyée (à brancher API)')),
              );
              context.pop();
            },
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

  Widget _inputField(String value, {bool valid = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: valid ? AppColors.cardBg : AppColors.surface,
          border: Border.all(
            color: valid ? AppColors.blue : AppColors.border,
            width: 1.5,
          ),
          borderRadius: AppDimensions.borderRadiusSm,
          boxShadow: [AppDimensions.cardShadowSm],
        ),
        child: Row(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valid ? AppColors.text : AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (valid)
              Icon(Icons.check, size: 16, color: AppColors.greenStatus)
            else
              Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textMuted),
          ],
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
    return Material(
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
            _permRow('Voir la position GPS de Bucky', true),
            _permRow('Recevoir les alertes en temps réel', true),
            _permRow('Ajouter une note de comportement', true),
            _permRow('Voir les données de santé passées', false),
            _permRow('Modifier le profil ou les zones', false),
          ],
        ),
      ),
    );
  }

  Widget _permRow(String label, bool allowed) {
    return Padding(
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
    );
  }
}

class _ConfirmRgpdModal extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ConfirmRgpdModal({required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(child: GestureDetector(onTap: onCancel, child: const SizedBox.expand())),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
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
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text.rich(
                    TextSpan(
                      text: 'En invitant ',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'Julie Martin',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        TextSpan(text: ' comme dog-sitter :'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.orangeLight,
                      border: Border.all(color: AppColors.orange.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('⚠️', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cette personne verra la position de Bucky et pourra en déduire vos habitudes et horaires pendant la garde.',
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
                        _confirmRow('Personne', 'Julie Martin'),
                        _confirmRow('Rôle', 'Dog-sitter'),
                        _confirmRow('Accès expire', '30 jan. 2026'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      child: const Text('✓ Confirmer l\'invitation'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onCancel,
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
          Text(
            key,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
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
