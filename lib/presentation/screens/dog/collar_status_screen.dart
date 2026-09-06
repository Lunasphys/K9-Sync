import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:k9sync/core/errors/app_error.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/entities/dog.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';
import 'package:k9sync/injection.dart';

String _relativeTime(DateTime? d) {
  if (d == null) return 'Jamais';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'Il y a ${diff.inSeconds}s';
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
  return 'Il y a ${diff.inDays} j';
}

/// Statut du collier : batterie, firmware, connexion — depuis la relation
/// Collar renvoyée par GET /dogs/:dogId.
class CollarStatusScreen extends StatefulWidget {
  const CollarStatusScreen({super.key, this.dogId});
  final String? dogId;

  @override
  State<CollarStatusScreen> createState() => _CollarStatusScreenState();
}

class _CollarStatusScreenState extends State<CollarStatusScreen> {
  bool _loading = true;
  String? _error;
  Dog? _dog;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dogId = widget.dogId;
    if (dogId == null) {
      setState(() {
        _loading = false;
        _error = 'Chien introuvable.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dog = await getIt<IDogRepository>().getDogById(dogId);
      if (!mounted) return;
      setState(() {
        _dog = dog;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is AppError
            ? (e.userMessage ?? 'Impossible de charger le collier.')
            : 'Impossible de charger le collier.';
      });
    }
  }

  Future<void> _goPair() async {
    final dogId = widget.dogId;
    if (dogId == null) return;
    final paired = await context.push<bool>('/dogs/$dogId/pair-collar');
    if (paired == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Collier')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final collar = _dog?.collar;
    if (collar == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔌', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                'Aucun collier jumelé pour ${_dog?.name ?? "ce chien"}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _goPair,
                child: const Text('Jumeler maintenant'),
              ),
            ],
          ),
        ),
      );
    }

    final batteryLevel = collar.batteryLevel;
    final batteryColor = batteryLevel == null
        ? AppColors.textMuted
        : batteryLevel < 15
        ? AppColors.redDanger
        : batteryLevel < 40
        ? AppColors.orange
        : AppColors.greenStatus;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border.all(color: AppColors.border, width: 1),
            borderRadius: AppDimensions.borderRadiusSm,
            boxShadow: [AppDimensions.cardShadowSm],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: collar.isOnline
                      ? AppColors.greenMint
                      : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.watch,
                  color: collar.isOnline ? AppColors.greenStatus : Colors.grey,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collar.serialNumber,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      collar.isOnline ? 'En ligne' : 'Hors ligne',
                      style: TextStyle(
                        fontSize: 12,
                        color: collar.isOnline
                            ? AppColors.greenStatus
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _statRow(
          icon: Icons.battery_full,
          label: 'Batterie',
          value: batteryLevel != null ? '$batteryLevel %' : 'Inconnue',
          valueColor: batteryColor,
        ),
        _statRow(
          icon: Icons.memory,
          label: 'Firmware',
          value: collar.firmwareVersion ?? 'Inconnu',
        ),
        _statRow(
          icon: Icons.wifi_tethering,
          label: 'Dernière connexion',
          value: _relativeTime(collar.lastSeenAt),
        ),
      ],
    );
  }

  Widget _statRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border, width: 1),
        borderRadius: AppDimensions.borderRadiusSm,
        boxShadow: [AppDimensions.cardShadowSm],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
