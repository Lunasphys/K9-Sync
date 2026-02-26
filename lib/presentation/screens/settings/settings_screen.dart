import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/presentation/router/route_guards.dart';

/// Paramètres (mockup) : carte utilisateur, Mon chien, Notifications, RGPD, Supprimer.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  'Paramètres',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _userCard(),
              _sectionLabel('Mon chien'),
              _settingsTile(
                icon: '🐕',
                iconBg: AppColors.cream,
                title: 'Profil de Bucky',
                onTap: () => context.push('/dogs/dog1'),
              ),
              _settingsTile(
                icon: '🐶',
                iconBg: AppColors.cream,
                title: 'Mes chiens',
                onTap: () => context.push(AppRoutes.dogList),
              ),
              _settingsTile(
                icon: '👥',
                iconBg: AppColors.blueLight,
                title: 'Accès partagés',
                trailing: '3 personnes',
                onTap: () {},
              ),
              _settingsTile(
                icon: '📡',
                iconBg: AppColors.greenMint,
                title: 'Collier GPS',
                trailing: '● En ligne',
                trailingColor: AppColors.greenStatus,
                onTap: () {},
              ),
              _sectionLabel('Notifications'),
              _settingsTile(
                icon: '🔔',
                iconBg: AppColors.yellowLight,
                title: 'Alertes GPS',
                trailingWidget: _buildSwitch(true),
              ),
              _settingsTile(
                icon: '❤️',
                iconBg: AppColors.pinkLight,
                title: 'Alertes santé',
                trailingWidget: _buildSwitch(true),
              ),
              _rgpdCard(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Material(
                  color: AppColors.redLight,
                  borderRadius: BorderRadius.circular(50),
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border, width: 2),
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [AppDimensions.cardShadowSm],
                      ),
                      child: const Center(
                        child: Text(
                          'Supprimer mon compte',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.redDanger,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orange,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppDimensions.cardShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border.all(color: AppColors.border, width: 2),
              shape: BoxShape.circle,
            ),
            child: const Center(
                child: Text('👤', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laurie D.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'laurie@email.com',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border.all(color: AppColors.border, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Free',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _settingsTile({
    required String icon,
    required Color iconBg,
    required String title,
    String? trailing,
    Color? trailingColor,
    Widget? trailingWidget,
    VoidCallback? onTap,
  }) {
    final trailingContent = trailingWidget ??
        (trailing != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (trailing.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        trailing,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: trailingColor ?? AppColors.textMuted,
                        ),
                      ),
                    ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              )
            : const Icon(Icons.chevron_right, color: AppColors.textMuted));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Material(
        color: AppColors.cardBg,
        borderRadius: AppDimensions.borderRadiusSm,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppDimensions.borderRadiusSm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 2),
              borderRadius: AppDimensions.borderRadiusSm,
              boxShadow: [AppDimensions.cardShadowSm],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBg,
                    border: Border.all(color: AppColors.border, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                      child: Text(icon, style: const TextStyle(fontSize: 16))),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                )),
                trailingContent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitch(bool value) {
    return Switch(
      value: value,
      onChanged: (_) {},
      activeTrackColor: AppColors.blue,
    );
  }

  Widget _rgpdCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blueLight,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: AppDimensions.borderRadiusSm,
        boxShadow: [AppDimensions.cardShadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔒 Confidentialité & Données',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gérez vos consentements, téléchargez ou supprimez vos données personnelles.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('📥 Télécharger'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push(AppRoutes.privacy),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('✏️ Consentements'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
