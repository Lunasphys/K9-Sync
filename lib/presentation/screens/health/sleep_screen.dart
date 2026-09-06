import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:k9sync/core/errors/app_error.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/enums/sleep_phase.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';
import 'package:k9sync/domain/interfaces/repositories/i_health_repository.dart';
import 'package:k9sync/injection.dart';

String _phaseLabel(SleepPhase phase) {
  switch (phase) {
    case SleepPhase.awake:
      return 'Éveillé';
    case SleepPhase.light:
      return 'Sommeil léger';
    case SleepPhase.deep:
      return 'Sommeil profond';
  }
}

Color _phaseColor(SleepPhase phase) {
  switch (phase) {
    case SleepPhase.awake:
      return AppColors.orange;
    case SleepPhase.light:
      return AppColors.blue;
    case SleepPhase.deep:
      return const Color(0xFF3F3D9E);
  }
}

/// Répartition des phases de sommeil (éveillé/léger/profond) sur les
/// dernières 24h ou 7 jours — GET /dogs/:dogId/sleep, alimenté par
/// ActivityRecord.sleepPhase (télémétrie MQTT + sync app).
class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  bool _loading = true;
  String? _error;
  SleepBreakdown? _breakdown;
  String _dogName = 'mon chien';
  int _days = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dogs = await getIt<IDogRepository>().getDogs();
      if (dogs.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Aucun chien enregistré.';
        });
        return;
      }
      final dog = dogs.first;
      final breakdown = await getIt<IHealthRepository>().getSleepBreakdown(
        dog.id,
        days: _days,
      );
      if (!mounted) return;
      setState(() {
        _dogName = dog.name;
        _breakdown = breakdown;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is AppError
            ? (e.userMessage ?? 'Impossible de charger les données de sommeil.')
            : 'Impossible de charger les données de sommeil.';
      });
    }
  }

  void _changeDays(int days) {
    if (days == _days) return;
    setState(() => _days = days);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Sommeil',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _PeriodToggle(days: _days, onChanged: _changeDays),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
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

    final breakdown = _breakdown;
    if (breakdown == null || breakdown.totalRecords == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('😴', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                'Aucune donnée de sommeil pour $_dogName sur '
                '${_days == 1 ? 'les dernières 24h' : 'les 7 derniers jours'}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Les données apparaîtront dès que le collier en transmettra.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border.all(color: AppColors.border, width: 2),
            borderRadius: AppDimensions.borderRadius,
            boxShadow: [AppDimensions.cardShadow],
          ),
          child: Column(
            children: [
              Semantics(
                label:
                    'Camembert de répartition du sommeil : '
                    '${breakdown.phases.map((p) => '${_phaseLabel(p.phase)} ${p.percentage.toStringAsFixed(0)}%').join(', ')}',
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 40,
                        sections: breakdown.phases.map((p) {
                          return PieChartSectionData(
                            value: p.count.toDouble(),
                            color: _phaseColor(p.phase),
                            title: '${p.percentage.toStringAsFixed(0)}%',
                            radius: 46,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final p in breakdown.phases) _phaseRow(p),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '${breakdown.totalRecords} relevés sur '
            '${breakdown.days == 1 ? 'les dernières 24h' : '${breakdown.days} derniers jours'}',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _phaseRow(SleepPhaseShare p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _phaseColor(p.phase),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _phaseLabel(p.phase),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${p.percentage.toStringAsFixed(0)}% · ${p.count}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  final int days;
  final ValueChanged<int> onChanged;
  const _PeriodToggle({required this.days, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _chip('24h', 1)),
        const SizedBox(width: 8),
        Expanded(child: _chip('7 jours', 7)),
      ],
    );
  }

  Widget _chip(String label, int value) {
    final selected = days == value;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Période $label',
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.orange : AppColors.cardBg,
            border: Border.all(
              color: selected ? AppColors.orange : AppColors.border,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
