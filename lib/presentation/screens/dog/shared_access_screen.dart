import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:k9sync/core/theme/app_theme.dart';

/// Accès partagés (mockup light) : liste Famille / Dog-sitters, export vétérinaire, bouton Inviter.
class SharedAccessScreen extends StatelessWidget {
  const SharedAccessScreen({super.key, this.dogId});
  final String? dogId;

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
          'Accès partagés',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.blueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, color: AppColors.blue, size: 20),
            ),
            onPressed: () => context.push('/dogs/${dogId ?? "dog1"}/invite'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border, width: 1),
                  borderRadius: AppDimensions.borderRadiusSm,
                  boxShadow: [AppDimensions.cardShadowSm],
                ),
                child: Row(
                  children: [
                    const Text('🐕', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bucky',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Collier SIM-001 · Vous êtes propriétaire',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _sectionLabel('Famille · accès permanent'),
            _sharedUserTile(
              context,
              initial: 'M',
              name: 'Marie Dupont',
              sub: 'marie@gmail.com',
              role: 'Famille',
              roleColor: AppColors.greenStatus,
              online: true,
            ),
            _divider(),
            _sectionLabel('Dog-sitters · accès temporaire'),
            _sharedUserTile(
              context,
              initial: 'J',
              name: 'Julie Martin',
              sub: 'Expire dans 3 jours',
              subColor: AppColors.orange,
              role: 'Dog-sitter',
              roleColor: AppColors.orange,
              onTap: () => _showSharedUserDetail(context),
            ),
            _divider(),
            _sharedUserTile(
              context,
              initial: 'T',
              name: 'Thomas Bernard',
              sub: 'Accès expiré · 12 jan.',
              role: 'Expiré',
              roleColor: AppColors.textMuted,
              faded: true,
            ),
            _divider(),
            _sectionLabel('Partage vétérinaire'),
            _vetExportTile(context),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/dogs/${dogId ?? "dog1"}/invite'),
                  child: const Text('+ Inviter quelqu\'un'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSharedUserDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SharedUserDetailSheet(
        name: 'Julie Martin',
        email: 'julie.m@gmail.com',
        role: 'Dog-sitter',
        expireText: 'Expire le 30 janvier 2026',
        progress: 0.3,
        onRevoke: () => Navigator.pop(ctx),
        onExtend: () => Navigator.pop(ctx),
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

  Widget _sharedUserTile(
    BuildContext context, {
    required String initial,
    required String name,
    required String sub,
    Color? subColor,
    required String role,
    required Color roleColor,
    bool online = false,
    bool faded = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.cardBg,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: faded ? 0.45 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: faded
                              ? [AppColors.surface, AppColors.surface]
                              : [AppColors.blue, AppColors.blueLight],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: faded ? AppColors.textMuted : AppColors.text,
                          ),
                        ),
                      ),
                    ),
                    if (online)
                      Positioned(
                        bottom: 1,
                        right: 1,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.greenStatus,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      if (subColor != null)
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: subColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              sub,
                              style: TextStyle(
                                fontSize: 12,
                                color: subColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          sub,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: faded ? AppColors.surface : (roleColor == AppColors.greenStatus ? AppColors.greenMint : AppColors.orangeLight),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    role,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: roleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vetExportTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: AppColors.cardBg,
        borderRadius: AppDimensions.borderRadiusSm,
        child: InkWell(
          onTap: () {},
          borderRadius: AppDimensions.borderRadiusSm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 1),
              borderRadius: AppDimensions.borderRadiusSm,
              boxShadow: [AppDimensions.cardShadowSm],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.blueLight,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [AppDimensions.cardShadowSm],
                  ),
                  child: const Icon(Icons.medical_services_outlined, color: AppColors.blue, size: 20),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export vétérinaire (PDF)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        'Données santé uniquement · jamais de GPS',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.border,
    );
  }
}

class _SharedUserDetailSheet extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final String expireText;
  final double progress;
  final VoidCallback onRevoke;
  final VoidCallback onExtend;

  const _SharedUserDetailSheet({
    required this.name,
    required this.email,
    required this.role,
    required this.expireText,
    required this.progress,
    required this.onRevoke,
    required this.onExtend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
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
            Text(
              name,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.orangeLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                role,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.orange,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.orangeLight,
                border: Border.all(color: AppColors.orange.withOpacity(0.25)),
                borderRadius: AppDimensions.borderRadiusSm,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '⏱ Accès temporaire',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.orange,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.orangeLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '3 jours',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    expireText,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.surface,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onExtend,
                          child: const Text('Prolonger'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          onPressed: onRevoke,
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.redLight,
                            foregroundColor: AppColors.redDanger,
                          ),
                          child: const Text('Révoquer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.only(left: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PERMISSIONS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _permRow('📍 Position GPS temps réel', true),
            _permRow('🔔 Alertes temps réel', true),
            _permRow('📝 Ajouter note comportement', true),
            _permRow('📊 Historique santé', false),
            _permRow('🗺 Parcours historiques', false),
            _permRow('✏️ Modifier profil / zones', false),
          ],
        ),
      ),
    );
  }

  Widget _permRow(String label, bool allowed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: allowed ? AppColors.text : AppColors.textMuted,
            ),
          ),
          Icon(
            allowed ? Icons.check : Icons.close,
            size: 16,
            color: allowed ? AppColors.greenStatus : AppColors.redDanger,
          ),
        ],
      ),
    );
  }
}
