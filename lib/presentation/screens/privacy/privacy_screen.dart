import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:k9sync/core/theme/app_theme.dart';

/// Confidentialité (mockup light) : 4 sections RGPD — consentements, export, durées, suppression.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

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
          'Confidentialité',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('1 — Mes consentements'),
            _consentBlock(context),
            _sectionLabel('2 — Mes données'),
            _exportCard(context),
            _sectionLabel('3 — Durées de conservation'),
            _retentionBlock(),
            _sectionLabel('4 — Supprimer mon compte'),
            _deleteBlock(context),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _consentBlock(BuildContext context) {
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
            _consentItem(
              title: 'Conditions générales',
              desc: 'Accepté le 14 jan. 2025 · v1.0',
              checked: true,
              onTap: () {},
            ),
            _divider(),
            _consentItem(
              title: 'Collecte données GPS',
              desc: 'Inclut déplacements indirects du propriétaire · v1.0',
              checked: true,
              onTap: () {},
            ),
            _divider(),
            _consentItem(
              title: 'Données de santé animale',
              desc: 'FC, température, activité · v1.0',
              checked: true,
              onTap: () {},
            ),
            _consentItem(
              title: 'Fonctionnalités communautaires',
              desc: 'Non activé · opt-in requis',
              checked: false,
              onTap: () {},
              trailing: Switch(
                value: false,
                onChanged: (_) {},
                activeTrackColor: AppColors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _consentItem({
    required String title,
    required String desc,
    required bool checked,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Material(
      color: AppColors.cardBg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: checked ? AppColors.blue : AppColors.cardBg,
                  border: Border.all(
                    color: checked ? AppColors.blue : AppColors.border,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: checked
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing else const Icon(Icons.chevron_right, size: 14, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.blueLight, AppColors.blueLight],
          ),
          border: Border.all(color: AppColors.blue.withOpacity(0.15)),
          borderRadius: AppDimensions.borderRadiusSm,
          boxShadow: [AppDimensions.cardShadowSm],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [AppDimensions.cardShadowSm],
              ),
              child: const Center(child: Text('📦', style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Télécharger mes données',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Archive ZIP · JSON + CSV · sous 30 jours',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.blue,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.blue.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Text(
                'Exporter',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _retentionBlock() {
    final items = [
      ('📍 Points GPS bruts', 'puis agrégation en statistiques', '90 jours'),
      ('💓 Données de santé', 'puis agrégation mensuelle', '12 mois'),
      ('🌐 Logs serveur', null, '3 mois'),
      ('📝 Notes dog-sitter', 'supprimées à expiration', 'Variable'),
      ('✅ Consentements', 'preuve légale', 'Indéfini'),
    ];
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
            for (var i = 0; i < items.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].$1,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.text,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (items[i].$2 != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              items[i].$2!,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: items[i].$3 == 'Indéfini' ? AppColors.greenMint : AppColors.blueLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        items[i].$3,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: items[i].$3 == 'Indéfini' ? AppColors.greenStatus : AppColors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (i < items.length - 1)
                Divider(height: 1, color: AppColors.border),
            ],
          ],
        ),
      ),
    );
  }

  Widget _deleteBlock(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.redLight,
              border: Border.all(color: AppColors.redDanger.withOpacity(0.2)),
              borderRadius: AppDimensions.borderRadiusSm,
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⚠️', style: TextStyle(fontSize: 20)),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Action irréversible',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.redDanger,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Compte, chiens, historique GPS et santé, accès partagés — tout sera supprimé sous 30 jours.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _inputLabel('CONFIRMEZ VOTRE MOT DE PASSE'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border, width: 1.5),
              borderRadius: AppDimensions.borderRadiusSm,
              boxShadow: [AppDimensions.cardShadowSm],
            ),
            child: Row(
              children: [
                Text(
                  '••••••••',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: AppColors.redLight,
            borderRadius: AppDimensions.borderRadiusSm,
            child: InkWell(
              onTap: () {},
              borderRadius: AppDimensions.borderRadiusSm,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.redDanger.withOpacity(0.25)),
                  borderRadius: AppDimensions.borderRadiusSm,
                ),
                child: const Center(
                  child: Text(
                    'Supprimer définitivement mon compte',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.redDanger,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Un email de confirmation vous sera envoyé.\nExécution sous 30 jours (RGPD art. 17).',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
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

  Widget _divider() {
    return Divider(height: 1, color: AppColors.border);
  }
}
