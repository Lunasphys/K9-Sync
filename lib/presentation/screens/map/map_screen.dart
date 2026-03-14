import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:k9sync/core/debug/debug_logger.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/entities/trail.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';
import 'package:k9sync/domain/interfaces/services/i_mqtt_service.dart';
import 'package:k9sync/injection.dart';
import 'package:k9sync/presentation/router/route_guards.dart';
import 'package:k9sync/presentation/providers/trail_provider.dart';

// Parsed GPS point from MQTT payload
class _GpsPoint {
  final double lat;
  final double lng;
  final double accuracy;
  final DateTime recordedAt;

  const _GpsPoint({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.recordedAt,
  });

  factory _GpsPoint.fromJson(Map<String, dynamic> json) {
    return _GpsPoint(
      lat: (json['latitude'] as num).toDouble(),
      lng: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      recordedAt: DateTime.tryParse(json['recordedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  _GpsPoint? _lastGps;
  bool _mqttConnected = false;
  StreamSubscription<bool>? _connectionStateSub;
  Timer? _ticker;

  // Trail tracking state
  bool _isTracking = false;
  DateTime? _trailStartedAt;
  Timer? _inactivityTimer;

  // Current session GPS points
  final List<LatLng> _trail = [];

  final _mapController = MapController();
  bool _followDog = true;

  String _dogName = 'Mon chien';

  static const _collarSerial = 'SIM001';
  static const _defaultCenter = LatLng(45.7578, 4.8320);

  @override
  void initState() {
    super.initState();
    _initMqtt();
    _loadDogName();
    // Refresh "Il y a Xs" label every second
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _lastGps != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _inactivityTimer?.cancel();
    _connectionStateSub?.cancel();
    getIt<IMqttService>().disconnect();
    super.dispose();
  }

  void _initMqtt() {
    final mqtt = getIt<IMqttService>();
    _connectionStateSub = mqtt.connectionState.listen((connected) {
      if (!mounted) return;
      setState(() => _mqttConnected = connected);
      if (connected) _subscribeToTopics(mqtt);
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

  void _subscribeToTopics(IMqttService mqtt) {
    mqtt.subscribeToGps((topic, payload) {
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final point = _GpsPoint.fromJson(json);
        if (!mounted) return;
        setState(() {
          _lastGps = point;
          final ll = LatLng(point.lat, point.lng);

          // Only record points when a trail is active
          if (_isTracking) {
            _trail.add(ll);
            if (_trail.length > 500) _trail.removeAt(0);

            // Reset inactivity timer — auto-end after 10s without movement
            _inactivityTimer?.cancel();
            _inactivityTimer = Timer(
              const Duration(seconds: 10),
              _autoEndTrail,
            );
          }

          if (_followDog) {
            _mapController.move(ll, _mapController.camera.zoom);
          }
        });
      } catch (e) {
        DebugLogger.collar('GPS parse error: $e');
      }
    });
  }

  // Start a new trail — clears current points
  void _startTrail() {
    setState(() {
      _isTracking = true;
      _trailStartedAt = DateTime.now();
      _trail.clear();
    });
  }

  // End the current trail and save it
  void _endTrail() {
    _inactivityTimer?.cancel();
    if (_trail.length < 2) {
      setState(() => _isTracking = false);
      return;
    }
    final saved = Trail(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startedAt: _trailStartedAt!,
      endedAt: DateTime.now(),
      points: List.from(_trail),
      distanceMeters: _computeTrailDistance(),
    );
    ref.read(trailListProvider.notifier).addTrail(saved);
    setState(() {
      _isTracking = false;
      _trail.clear();
    });
    DebugLogger.gps(
      'Trail saved — ${saved.points.length} pts, '
      '${(saved.distanceMeters / 1000).toStringAsFixed(2)}km',
    );
  }

  void _autoEndTrail() {
    if (_isTracking) _endTrail();
  }

  String get _locationLabel {
    if (_lastGps == null) return 'En attente du signal...';
    return '${_lastGps!.lat.toStringAsFixed(5)}, '
        '${_lastGps!.lng.toStringAsFixed(5)}';
  }

  String get _lastSeenLabel {
    if (_lastGps == null) return '–';
    final diff = DateTime.now().difference(_lastGps!.recordedAt);
    if (diff.inSeconds < 60) return 'Il y a ${diff.inSeconds}s';
    return 'Il y a ${diff.inMinutes}min';
  }

  LatLng get _currentCenter =>
      _lastGps != null ? LatLng(_lastGps!.lat, _lastGps!.lng) : _defaultCenter;

  double _computeTrailDistance() {
    final dist = const Distance();
    double total = 0;
    for (int i = 1; i < _trail.length; i++) {
      total += dist(_trail[i - 1], _trail[i]);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final savedTrails = ref.watch(trailListProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // ── OSM map ────────────────────────────────────────────
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentCenter,
                    initialZoom: 16,
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture && _followDog) {
                        setState(() => _followDog = false);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.k9sync',
                    ),
                    if (_isTracking && _trail.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _trail,
                            color: AppColors.orange.withValues(alpha: 0.8),
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    if (_lastGps != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_lastGps!.lat, _lastGps!.lng),
                            width: 60,
                            height: 72,
                            child: _DogMarker(live: _mqttConnected),
                          ),
                        ],
                      ),
                  ],
                ),

                // ── MQTT badge ─────────────────────────────────────────
                Positioned(
                  top: 60,
                  left: 16,
                  child: _MqttBadge(connected: _mqttConnected),
                ),

                // ── Follow button ──────────────────────────────────────
                if (!_followDog)
                  Positioned(
                    top: 60,
                    right: 16,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _followDog = true);
                        if (_lastGps != null) {
                          _mapController.move(
                            LatLng(_lastGps!.lat, _lastGps!.lng),
                            _mapController.camera.zoom,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          border: Border.all(
                              color: AppColors.border, width: 2),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [AppDimensions.cardShadowSm],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.my_location,
                                size: 14, color: AppColors.orange),
                            const SizedBox(width: 5),
                            Text(
                              'Suivre $_dogName',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Search bar ─────────────────────────────────────────
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
                      _mapIconBtn(
                        Icons.history,
                        () => context.push('/home/carte/history'),
                      ),
                      const SizedBox(width: 8),
                      _mapIconBtn(Icons.pets, () => context.push(AppRoutes.lostMode)),
                    ],
                  ),
                ),

                // ── Start / Stop trail button ──────────────────────────
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _isTracking
                      ? ElevatedButton.icon(
                          onPressed: _endTrail,
                          icon: const Icon(Icons.stop),
                          label: const Text('Terminer la balade'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: _startTrail,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(savedTrails.isEmpty
                              ? 'Démarrer une balade'
                              : 'Nouvelle balade (${savedTrails.length} sauvegardée${savedTrails.length > 1 ? 's' : ''})'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.orange,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                ),
              ],
            ),
          ),

          // ── Bottom info card ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border:
                  Border(top: BorderSide(color: AppColors.border, width: 2)),
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
                          child: Text('🐕',
                              style: TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_dogName,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900)),
                          Text(
                            '$_locationLabel · $_lastSeenLabel',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(connected: _mqttConnected),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _mapStat(
                      _lastGps != null
                          ? '${_lastGps!.accuracy.toStringAsFixed(1)}m'
                          : '–',
                      'Précision',
                    ),
                    const SizedBox(width: 8),
                    _mapStat(
                      _trail.length > 1
                          ? '${(_computeTrailDistance() / 1000).toStringAsFixed(2)}km'
                          : '–',
                      'Distance',
                    ),
                    const SizedBox(width: 8),
                    _mapStat(
                      _isTracking ? '${_trail.length}' : '–',
                      'Points GPS',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => context.push('/home/carte/history'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      border: Border.all(color: AppColors.border, width: 2),
                      borderRadius: AppDimensions.borderRadiusSm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 16, color: AppColors.orange),
                        const SizedBox(width: 6),
                        Text(
                          'Voir les balades',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
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
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ── Extracted widgets ─────────────────────────────────────────────────────────

class _DogMarker extends StatelessWidget {
  final bool live;
  const _DogMarker({required this.live});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border.all(color: AppColors.border, width: 3),
            shape: BoxShape.circle,
            boxShadow: [AppDimensions.cardShadow],
          ),
          child: const Center(
              child: Text('🐕', style: TextStyle(fontSize: 26))),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: live ? AppColors.orange : Colors.grey.shade400,
            border: Border.all(color: AppColors.border, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            live ? 'Live' : 'Hors ligne',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _MqttBadge extends StatelessWidget {
  final bool connected;
  const _MqttBadge({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: connected ? AppColors.greenMint : Colors.grey.shade200,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: connected ? AppColors.greenStatus : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            connected ? 'MQTT • Live' : 'MQTT • Off',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool connected;
  const _StatusChip({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: connected ? AppColors.greenMint : Colors.grey.shade200,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: connected ? AppColors.greenStatus : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            connected ? 'En ligne' : 'Hors ligne',
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}