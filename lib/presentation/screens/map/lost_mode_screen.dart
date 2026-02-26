import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:k9sync/core/theme/app_theme.dart';

/// Mode Chien perdu (mockup) : fond sombre, carte, marqueur, actions sonore/lumineux.
class LostModeScreen extends StatelessWidget {
  const LostModeScreen({super.key});

  static const Color _darkBg = Color(0xFF1A1A1A);
  static const Color _darkCard = Color(0xFF2C2C2C);
  static const Color _darkBorder = Color(0xFF444444);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1a2a1a),
                          Color(0xFF152015),
                          Color(0xFF1a2a1a),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          border: Border.all(color: _darkBorder),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '📍 Dernière position — Il y a 2 min',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.orange,
                            border: Border.all(color: Colors.white, width: 3),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.orange.withOpacity(0.6),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: const Center(
                              child:
                                  Text('🐕', style: TextStyle(fontSize: 30))),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildBottomPanel(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _darkCard,
                border: Border.all(color: _darkBorder, width: 2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Mode Chien Perdu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4444),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '● ACTIF',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: _darkBg,
        border: Border(top: BorderSide(color: const Color(0xFF333333), width: 2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _darkCard,
              border: Border.all(color: AppColors.orange, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recherche en cours...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Alertes envoyées aux utilisateurs proches · 3 km',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _actionCard(
                      emoji: '🔊', label: 'Signal sonore', onTap: () {})),
              const SizedBox(width: 8),
              Expanded(
                  child: _actionCard(
                      emoji: '💡', label: 'Signal lumineux', onTap: () {})),
              const SizedBox(width: 8),
              Expanded(
                  child:
                      _actionCard(emoji: '📞', label: 'Appeler aide', onTap: () {})),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => context.pop(),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF3C3C3C),
                foregroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                  side: const BorderSide(color: Color(0xFF555555), width: 2),
                ),
              ),
              child: const Text('Désactiver le mode perdu'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
      {required String emoji, required String label, required VoidCallback onTap}) {
    return Material(
      color: _darkCard,
      borderRadius: AppDimensions.borderRadiusSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDimensions.borderRadiusSm,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: _darkBorder, width: 2),
            borderRadius: AppDimensions.borderRadiusSm,
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
