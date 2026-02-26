import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/presentation/router/route_guards.dart';

/// Historique des parcours (mockup) : stats du mois, liste cette semaine.
class TrailHistoryScreen extends StatelessWidget {
  const TrailHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Parcours',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text)),
            Text(
              'Bucky · Ce mois',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          _iconBtn(Icons.calendar_today_outlined, () {}),
          const SizedBox(width: 8),
          _iconBtn(Icons.map_outlined, () {}),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 14),
            Row(
              children: [
                _statCard('28.4', 'km', 'Ce mois'),
                const SizedBox(width: 8),
                _statCard('42', '', 'Sorties'),
                const SizedBox(width: 8),
                _statCard('6h12', '', 'Actif'),
              ],
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Cette semaine',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _trailTile(
              context,
              emoji: '🌿',
              bgColor: AppColors.greenMint,
              title: 'Promenade du matin',
              subtitle: 'Aujourd\'hui · 8h14 · 32 min',
              distance: '1.2km',
            ),
            _trailTile(
              context,
              emoji: '🏃',
              bgColor: AppColors.orangeLight,
              title: 'Grande sortie parc',
              subtitle: 'Hier · 17h30 · 58 min',
              distance: '3.4km',
              onTap: () => context.push('${AppRoutes.trailHistory}/detail'),
            ),
            _trailTile(
              context,
              emoji: '🌿',
              bgColor: AppColors.greenMint,
              title: 'Tour du quartier',
              subtitle: 'Lundi · 7h45 · 20 min',
              distance: '0.8km',
            ),
            _trailTile(
              context,
              emoji: '🏃',
              bgColor: AppColors.orangeLight,
              title: 'Sortie en famille',
              subtitle: 'Dimanche · 10h00 · 1h20',
              distance: '5.1km',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border.all(color: AppColors.border, width: 2),
            shape: BoxShape.circle,
            boxShadow: [AppDimensions.cardShadowSm],
          ),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }

  Widget _statCard(String value, String unit, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.border, width: 2),
          borderRadius: AppDimensions.borderRadiusSm,
          boxShadow: [AppDimensions.cardShadowSm],
        ),
        child: Column(
          children: [
            Text.rich(
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
                children: [
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: unit,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trailTile(
    BuildContext context, {
    required String emoji,
    required Color bgColor,
    required String title,
    required String subtitle,
    required String distance,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.cardBg,
        borderRadius: AppDimensions.borderRadiusSm,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppDimensions.borderRadiusSm,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 2),
              borderRadius: AppDimensions.borderRadiusSm,
              boxShadow: [AppDimensions.cardShadowSm],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border.all(color: AppColors.border, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 20))),
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
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  distance,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
