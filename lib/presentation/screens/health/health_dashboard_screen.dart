import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:k9sync/application/health/sync_offline_health_use_case.dart';
import 'package:k9sync/core/debug/debug_logger.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/interfaces/repositories/i_auth_repository.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';
import 'package:k9sync/domain/interfaces/services/i_mqtt_service.dart';
import 'package:k9sync/injection.dart';
import 'package:k9sync/presentation/providers/health_provider.dart';
import 'package:k9sync/presentation/router/route_guards.dart';

class HealthDashboardScreen extends ConsumerStatefulWidget {
  const HealthDashboardScreen({super.key});

  @override
  ConsumerState<HealthDashboardScreen> createState() =>
      _HealthDashboardScreenState();
}

class _HealthDashboardScreenState
    extends ConsumerState<HealthDashboardScreen>
    with WidgetsBindingObserver {
  static const _collarSerial = 'SIM001';
  StreamSubscription<bool>? _connectionSub;
  bool _mqttConnected = false;
  Timer? _ticker;
  String? _cachedDogId;
  String _dogName = 'Mon chien';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initMqtt();
    _loadDogName();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _getDogId().then((dogId) async {
      if (dogId == null || !mounted) return;
      try {
        await getIt<SyncOfflineHealthUseCase>().call(dogId);
      } catch (e) {
        DebugLogger.health('Sync offline health failed: $e');
      }
    });
  }

  Future<String?> _getDogId() async {
    if (_cachedDogId != null) return _cachedDogId;
    try {
      final user = await getIt<IAuthRepository>().getCurrentUser();
      if (user == null) return null;
      final dogs = await getIt<IDogRepository>().getDogs();
      final id = dogs.isNotEmpty ? dogs.first.id : null;
      if (id != null) _cachedDogId = id;
      return id;
    } catch (_) {
      return null;
    }
  }

  void _initMqtt() {
    final mqtt = getIt<IMqttService>();
    _connectionSub = mqtt.connectionState.listen((connected) {
      if (!mounted) return;
      setState(() => _mqttConnected = connected);
      if (connected) _subscribeHealth(mqtt);
    });
    mqtt.connect(collarSerial: _collarSerial);
  }

  Future<void> _loadDogName() async {
    try {
      final dogs = await getIt<IDogRepository>().getDogs();
      if (dogs.isNotEmpty && mounted) {
        setState(() => _dogName = dogs.first.name);
      }
    } catch (_) {}
  }

  void _subscribeHealth(IMqttService mqtt) {
    mqtt.subscribeToHealth((topic, payload) {
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final snap = HealthSnapshot.fromJson(json);
        ref.read(healthProvider.notifier).onSnapshot(snap);
      } catch (e) {
        DebugLogger.health('Health parse error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(healthProvider);
    final latest = state.latest;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Santé',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.pets),
            onPressed: () => context.push(AppRoutes.lostMode),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _MqttDot(connected: _mqttConnected),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.border),
        ),
      ),
      body: latest == null
          ? _WaitingState(connected: _mqttConnected)
          : _Dashboard(
              latest: latest,
              history: state.history,
              todayActivity: state.todayActivity,
              dogName: _dogName,
            ),
    );
  }
}

// ── Waiting state ─────────────────────────────────────────────────────────────

class _WaitingState extends StatelessWidget {
  final bool connected;
  const _WaitingState({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🐕', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            connected ? 'En attente des données...' : 'Collier hors ligne',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            connected
                ? 'Les capteurs s\'afficheront dès la première mesure.'
                : 'Lance le simulateur pour voir les données.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Main dashboard ────────────────────────────────────────────────────────────

class _Dashboard extends StatelessWidget {
  final HealthSnapshot latest;
  final List<HealthSnapshot> history;
  final DailyActivity todayActivity;
  final String dogName;

  const _Dashboard({
    required this.latest,
    required this.history,
    required this.todayActivity,
    required this.dogName,
  });

  @override
  Widget build(BuildContext context) {
    final isHrAnomaly = latest.heartRate > 180 || latest.heartRate < 50;
    final isTempAnomaly =
        latest.temperature > 39.5 || latest.temperature < 36.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DogHeader(latest: latest, todayActivity: todayActivity, dogName: dogName),
        const SizedBox(height: 16),
        if (latest.anomalyDetected) ...[
          _AnomalyBanner(type: latest.anomalyType),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: _VitalCard(
                icon: '❤️',
                label: 'Fréquence cardiaque',
                value: '${latest.heartRate}',
                unit: 'bpm',
                isAnomaly: isHrAnomaly,
                normalRange: '50–180 bpm',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _VitalCard(
                icon: '🌡️',
                label: 'Température',
                value: latest.temperature.toStringAsFixed(1),
                unit: '°C',
                isAnomaly: isTempAnomaly,
                normalRange: '36–39.5 °C',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ActivityCard(todayActivity: todayActivity),
        const SizedBox(height: 16),
        if (history.length > 2) ...[
          _SectionTitle('Fréquence cardiaque — 20 dernières mesures'),
          const SizedBox(height: 8),
          _HrChart(history: history),
          const SizedBox(height: 16),
          _SectionTitle('Température corporelle — 20 dernières mesures'),
          const SizedBox(height: 8),
          _TempChart(history: history),
          const SizedBox(height: 16),
        ],
        Center(
          child: Text(
            'Dernière mise à jour : ${_ago(latest.recordedAt)}',
            style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'il y a ${diff.inSeconds}s';
    return 'il y a ${diff.inMinutes}min';
  }
}

// ── Dog header ────────────────────────────────────────────────────────────────

class _DogHeader extends StatelessWidget {
  final HealthSnapshot latest;
  final DailyActivity todayActivity;
  final String dogName;
  const _DogHeader({
    required this.latest,
    required this.todayActivity,
    required this.dogName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: AppDimensions.borderRadius,
        boxShadow: [AppDimensions.cardShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.cream,
              border: Border.all(color: AppColors.border, width: 2),
              shape: BoxShape.circle,
            ),
            child: const Center(
                child: Text('🐕', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dogName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900)),
                // Uses persisted daily totals, not the raw snapshot value
                Text(
                  '${todayActivity.steps} pas · '
                  '${todayActivity.activeMinutes}min actif aujourd\'hui',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          _StatusDot(
            ok: !latest.anomalyDetected,
            label: latest.anomalyDetected ? 'Anomalie' : 'Normal',
          ),
        ],
      ),
    );
  }
}

// ── Anomaly banner ────────────────────────────────────────────────────────────

class _AnomalyBanner extends StatelessWidget {
  final String type;
  const _AnomalyBanner({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        border: Border.all(color: Colors.red.shade300, width: 2),
        borderRadius: AppDimensions.borderRadiusSm,
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Anomalie détectée : $type',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vital card ────────────────────────────────────────────────────────────────

class _VitalCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final String unit;
  final bool isAnomaly;
  final String normalRange;

  const _VitalCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.isAnomaly,
    required this.normalRange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAnomaly ? const Color(0xFFFFF0F0) : AppColors.cardBg,
        border: Border.all(
          color: isAnomaly ? Colors.red.shade400 : AppColors.border,
          width: 2,
        ),
        borderRadius: AppDimensions.borderRadius,
        boxShadow: [AppDimensions.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const Spacer(),
              if (isAnomaly)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: isAnomaly ? Colors.red : AppColors.text,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(normalRange,
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Activity card — reads from persisted DailyActivity ────────────────────────

class _ActivityCard extends StatelessWidget {
  final DailyActivity todayActivity;
  const _ActivityCard({required this.todayActivity});

  @override
  Widget build(BuildContext context) {
    const goal = 5000;
    final progress = (todayActivity.steps / goal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: AppDimensions.borderRadius,
        boxShadow: [AppDimensions.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏃', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text('Activité du jour',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text('${todayActivity.steps} / $goal pas',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.bg,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _activityStat(
                  '${todayActivity.activeMinutes}min', 'Actif'),
              const SizedBox(width: 8),
              _activityStat(
                  '${(100 * progress).toStringAsFixed(0)}%', 'Objectif'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityStat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border, width: 2),
          borderRadius: AppDimensions.borderRadiusSm,
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900)),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Heart rate chart — last 20 points ─────────────────────────────────────────

class _HrChart extends StatelessWidget {
  final List<HealthSnapshot> history;
  const _HrChart({required this.history});

  static const double _minY = 30;
  static const double _maxY = 230;

  @override
  Widget build(BuildContext context) {
    final recent =
        history.length > 20 ? history.sublist(history.length - 20) : history;
    final spots = recent
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.heartRate.toDouble()))
        .toList();

    return _ChartContainer(
      child: LineChart(
        LineChartData(
          minY: _minY,
          maxY: _maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: Text('bpm',
                  style: TextStyle(
                      fontSize: 9, color: AppColors.textMuted)),
              axisNameSize: 14,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 50,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
              ),
            ),
            bottomTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 50,
                color: Colors.blue.withValues(alpha: 0.5),
                strokeWidth: 1,
                dashArray: [4, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  labelResolver: (_) => '50',
                  style: TextStyle(
                      fontSize: 9, color: Colors.blue.shade400),
                ),
              ),
              HorizontalLine(
                y: 180,
                color: Colors.red.withValues(alpha: 0.5),
                strokeWidth: 1,
                dashArray: [4, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  labelResolver: (_) => '180',
                  style: const TextStyle(
                      fontSize: 9, color: Colors.red),
                ),
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.red.shade400,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.red.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Temperature chart — last 20 points ───────────────────────────────────────

class _TempChart extends StatelessWidget {
  final List<HealthSnapshot> history;
  const _TempChart({required this.history});

  static const double _minY = 35.0;
  static const double _maxY = 41.0;

  @override
  Widget build(BuildContext context) {
    final recent =
        history.length > 20 ? history.sublist(history.length - 20) : history;
    final spots = recent
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.temperature))
        .toList();

    return _ChartContainer(
      child: LineChart(
        LineChartData(
          minY: _minY,
          maxY: _maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: Text('°C',
                  style: TextStyle(
                      fontSize: 9, color: AppColors.textMuted)),
              axisNameSize: 14,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 1,
                getTitlesWidget: (v, _) => Text('${v.toStringAsFixed(0)}°',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
              ),
            ),
            bottomTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 36.0,
                color: Colors.blue.withValues(alpha: 0.5),
                strokeWidth: 1,
                dashArray: [4, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  labelResolver: (_) => '36°',
                  style: TextStyle(
                      fontSize: 9, color: Colors.blue.shade400),
                ),
              ),
              HorizontalLine(
                y: 39.5,
                color: Colors.red.withValues(alpha: 0.5),
                strokeWidth: 1,
                dashArray: [4, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  labelResolver: (_) => '39.5°',
                  style: const TextStyle(
                      fontSize: 9, color: Colors.red),
                ),
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.orange,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.orange.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chart container ───────────────────────────────────────────────────────────

class _ChartContainer extends StatelessWidget {
  final Widget child;
  const _ChartContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: AppDimensions.borderRadius,
        boxShadow: [AppDimensions.cardShadow],
      ),
      child: child,
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900));
}

class _MqttDot extends StatelessWidget {
  final bool connected;
  const _MqttDot({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: connected ? AppColors.greenStatus : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(connected ? 'Live' : 'Off',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: connected ? AppColors.greenStatus : Colors.grey)),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool ok;
  final String label;
  const _StatusDot({required this.ok, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ok ? AppColors.greenMint : const Color(0xFFFFF0F0),
        border: Border.all(
          color: ok ? AppColors.greenStatus : Colors.red.shade300,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: ok ? AppColors.greenStatus : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: ok ? AppColors.greenStatus : Colors.red)),
        ],
      ),
    );
  }
}
