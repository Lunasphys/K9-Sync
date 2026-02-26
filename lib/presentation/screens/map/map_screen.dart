import 'package:flutter/material.dart';
import 'package:k9sync/core/theme/app_theme.dart';

/// Carte GPS temps réel (mockup) : zone carte, marqueur chien, barre basse avec infos.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Fond carte (dégradé vert)
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFD4E8C2),
                        Color(0xFFB8D4A8),
                        Color(0xFFC8DEB8),
                        Color(0xFFD8E8C4),
                      ],
                    ),
                  ),
                ),
                // Grille
                CustomPaint(
                  painter: _GridPainter(),
                  size: Size.infinite,
                ),
                // Barre recherche + boutons
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            border: Border.all(
                                color: AppColors.border, width: 2),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [AppDimensions.cardShadowSm],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search,
                                  size: 20, color: AppColors.textMuted),
                              const SizedBox(width: 8),
                              Text(
                                'Rechercher un lieu...',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _mapIconBtn(Icons.my_location, () {}),
                      const SizedBox(width: 8),
                      _mapIconBtn(Icons.settings_outlined, () {}),
                    ],
                  ),
                ),
                // Marqueur chien (centre)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          border: Border.all(
                              color: AppColors.border, width: 3),
                          shape: BoxShape.circle,
                          boxShadow: [AppDimensions.cardShadow],
                        ),
                        child: const Center(
                            child: Text('🐕', style: TextStyle(fontSize: 28))),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          border: Border.all(
                              color: AppColors.border, width: 2),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [AppDimensions.cardShadowSm],
                        ),
                        child: const Text(
                          'Bucky • En direct',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Carte basse
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 2),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.border,
                  offset: const Offset(0, -4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        border: Border.all(
                            color: AppColors.border, width: 2),
                        shape: BoxShape.circle,
                        boxShadow: [AppDimensions.cardShadowSm],
                      ),
                      child: const Center(
                          child: Text('🐕', style: TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bucky',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Jardin arrière · Il y a 30s',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.greenMint,
                        border: Border.all(
                            color: AppColors.border, width: 2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.greenStatus,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'En ligne',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _mapStat('847m', "Aujourd'hui"),
                    _mapStat('32min', 'Actif'),
                    _mapStat('12.4°C', 'Temp.'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapIconBtn(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          width: 42,
          height: 42,
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

  Widget _mapStat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border, width: 2),
          borderRadius: AppDimensions.borderRadiusSm,
          boxShadow: [AppDimensions.cardShadowSm],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
