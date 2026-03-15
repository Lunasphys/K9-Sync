import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/interfaces/services/i_mqtt_service.dart';
import 'package:k9sync/injection.dart';
import 'package:k9sync/presentation/providers/lost_mode_provider.dart';

class LostModeScreen extends ConsumerStatefulWidget {
  const LostModeScreen({super.key});

  @override
  ConsumerState<LostModeScreen> createState() => _LostModeScreenState();
}

class _LostModeScreenState extends ConsumerState<LostModeScreen>
    with SingleTickerProviderStateMixin {
  static const _collarSerial = 'SIM001';

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = ref.watch(lostModeProvider);

    if (isActive) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Mode Chien Perdu',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildStatusCard(isActive),
            const SizedBox(height: 16),
            _buildToggleButton(isActive),
            if (isActive) ...[
              const SizedBox(height: 12),
              _buildBeepButton(),
            ],
            const SizedBox(height: 24),
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isActive) {
    if (isActive) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _pulseAnimation.value,
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.redLight,
            border: Border.all(color: AppColors.redDanger, width: 2),
            borderRadius: AppDimensions.borderRadius,
            boxShadow: [AppDimensions.cardShadow],
          ),
          child: Row(
            children: [
              Text(
                '🚨',
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode Chien Perdu ACTIF',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.redDanger,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recherche en cours — alertes envoyées aux utilisateurs proches',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: AppDimensions.borderRadius,
        boxShadow: [AppDimensions.cardShadow],
      ),
      child: Row(
        children: [
          const Text('🐕', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode Chien Perdu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Désactivé — activez pour lancer une recherche',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(bool isActive) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => ref.read(lostModeProvider.notifier).toggle(),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? AppColors.redDanger : AppColors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
        ),
        child: Text(
          isActive ? 'Désactiver' : 'Activer le mode perdu',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildBeepButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          getIt<IMqttService>().publishBeep(_collarSerial, durationMs: 3000);
        },
        icon: const Icon(Icons.volume_up, size: 20),
        label: const Text('Faire biper'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: AppDimensions.borderRadiusSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'À propos du mode chien perdu',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Quand vous activez le mode chien perdu, une alerte est envoyée aux '
            'utilisateurs K9 Sync à proximité. Vous pouvez faire biper le collier '
            'pour aider à localiser votre chien.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
