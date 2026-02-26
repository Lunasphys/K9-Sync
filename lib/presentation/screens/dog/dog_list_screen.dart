import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/presentation/router/route_guards.dart';

/// Mes chiens (mockup light) : cartes chien en ligne/hors ligne, résumé global, accès rapides (MVP 1 chien).
class DogListScreen extends StatelessWidget {
  const DogListScreen({super.key});

  /// Pour la démo : true = plusieurs chiens, false = MVP 1 chien
  static const bool _multiDog = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: _backBtn(context),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _multiDog ? 'Mes chiens' : 'Mon chien',
          style: const TextStyle(
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
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_multiDog) ...[
              _dogCard(context, name: 'Bucky', breed: 'Golden Retriever · 3 ans', online: true, steps: '7 420 pas', progress: 0.74),
              _dogCard(context, name: 'Luna', breed: 'Caniche · 5 ans', online: false, steps: null, progress: 0),
              _addDogCard(context, title: 'Ajouter un chien', sub: 'Associer un nouveau collier'),
            ] else ...[
              _dogCard(context, name: 'Bucky', breed: 'Golden Retriever · 3 ans', online: true, steps: null, progress: null, chips: true),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  'ACCÈS RAPIDES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              _quickAccessRow(context, icon: Icons.location_on_outlined, title: 'Voir sur la carte', sub: 'Position en temps réel', onTap: () => context.push(AppRoutes.map)),
              _divider(),
              _quickAccessRow(context, icon: Icons.favorite_border, title: 'Données de santé', sub: 'FC, température, activité', onTap: () => context.push(AppRoutes.healthDashboard)),
              _divider(),
              _quickAccessRow(context, icon: Icons.people_outline, title: 'Accès partagés', sub: 'Famille, dog-sitter', onTap: () => context.push('/dogs/dog1/shared-access')),
              _addDogCard(context, title: 'Ajouter un 2e chien', sub: 'Associer un nouveau collier', compact: true),
            ],
            if (_multiDog) ...[
              _divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  'RÉSUMÉ GLOBAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: _miniStat('Colliers actifs', '1 / 2', AppColors.greenStatus)),
                    const SizedBox(width: 8),
                    Expanded(child: _miniStat('Alertes non lues', '3', AppColors.orange)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _backBtn(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.arrow_back, size: 18, color: AppColors.textMuted),
    );
  }

  Widget _dogCard(
    BuildContext context, {
    required String name,
    required String breed,
    required bool online,
    String? steps,
    double? progress,
    bool chips = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: AppColors.cardBg,
        borderRadius: AppDimensions.borderRadius,
        child: InkWell(
          onTap: () => context.push('/dogs/dog1'),
          borderRadius: AppDimensions.borderRadius,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 1),
              borderRadius: AppDimensions.borderRadius,
              boxShadow: [AppDimensions.cardShadowSm],
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.blue, AppColors.blueLight],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(child: Text('🐕', style: TextStyle(fontSize: 28))),
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
                      Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: online ? AppColors.greenMint : AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              online ? '● En ligne' : 'Hors ligne',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: online ? AppColors.greenStatus : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          breed,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (chips) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _chip('🔋 87%', AppColors.blueLight),
                            const SizedBox(width: 6),
                            _chip('♥ 82 bpm', AppColors.greenMint),
                          ],
                        ),
                      ],
                      if (steps != null || progress != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Activité aujourd'hui",
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                            Text(
                              steps ?? '—',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: online ? AppColors.greenStatus : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress ?? 0,
                            backgroundColor: AppColors.surface,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              online ? AppColors.greenStatus : AppColors.surface,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
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

  Widget _chip(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Widget _addDogCard(BuildContext context, {required String title, required String sub, bool compact = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 18 : 4, 16, compact ? 0 : 20),
      child: Container(
        padding: EdgeInsets.all(compact ? 14 : 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border, width: 2),
          borderRadius: AppDimensions.borderRadius,
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 44 : 64,
              height: compact ? 44 : 64,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(compact ? 14 : 20),
              ),
              child: const Center(child: Text('➕', style: TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: compact ? 14 : 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
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
          ],
        ),
      ),
    );
  }

  Widget _quickAccessRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String sub,
    VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.cardBg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.blueLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: AppColors.blue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
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
              const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
            ],
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

  Widget _miniStat(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 1),
        borderRadius: AppDimensions.borderRadiusSm,
        boxShadow: [AppDimensions.cardShadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
