import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:k9sync/core/debug/debug_logger.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/core/utils/photo_url.dart';
import 'package:k9sync/domain/entities/geofence.dart';
import 'package:k9sync/domain/entities/place_search_result.dart';
import 'package:k9sync/domain/entities/trail.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';
import 'package:k9sync/domain/interfaces/repositories/i_gps_repository.dart';
import 'package:k9sync/domain/interfaces/services/i_geocoding_service.dart';
import 'package:k9sync/domain/interfaces/services/i_mqtt_service.dart';
import 'package:k9sync/injection.dart';
import 'package:k9sync/presentation/router/route_guards.dart';
import 'package:k9sync/presentation/providers/trail_provider.dart';
import 'package:k9sync/presentation/widgets/common/live_badge.dart';

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
      recordedAt:
          DateTime.tryParse(json['recordedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
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

  // Drives both the marker glide and the "Suivre" camera pan from the
  // same interpolated value, so they move together instead of the marker
  // sliding smoothly while the camera jumps beside it.
  late final AnimationController _moveAnimCtrl;
  Animation<LatLng>? _moveAnim;
  static const _moveAnimDuration = Duration(milliseconds: 2500);

  // Consumer-grade GPS jitter is a few meters even standing still — below
  // this, a "new" point isn't a real step and shouldn't re-trigger the
  // marker/camera animation.
  static const _noiseThresholdMeters = 2.0;

  String _dogName = 'Mon chien';
  String? _dogPhotoUrl;
  Geofence? _geofenceZone;

  // Place search
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _searching = false;
  String? _searchError;
  List<PlaceSearchResult> _searchResults = [];
  bool _showSearchResults = false;

  static const _defaultCenter = LatLng(45.7578, 4.8320);

  @override
  void initState() {
    super.initState();
    _moveAnimCtrl = AnimationController(
      vsync: this,
      duration: _moveAnimDuration,
    )..addListener(_onMoveTick);
    _loadDogAndConnect();
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
    _searchController.dispose();
    _searchFocusNode.dispose();
    _moveAnimCtrl.dispose();
    getIt<IMqttService>().disconnect();
    super.dispose();
  }

  // Camera follows the exact same interpolated value the marker renders —
  // called on every animation tick, not through setState (MapController.move
  // pushes to FlutterMap's own camera stream, no rebuild needed here).
  void _onMoveTick() {
    if (!_followDog) return;
    final pos = _moveAnim?.value;
    if (pos != null) _mapController.move(pos, _mapController.camera.zoom);
  }

  // Places the marker/camera immediately, no glide — used only for the
  // very first position (seed from backend or first MQTT point), where
  // there is nothing to animate from yet.
  void _snapTo(LatLng target) {
    _moveAnim = LatLngTween(
      begin: target,
      end: target,
    ).animate(_moveAnimCtrl);
    // Triggers _onMoveTick synchronously, which places the camera too.
    _moveAnimCtrl.value = 1;
  }

  // Glides marker + camera together from wherever they currently are to
  // the new target over [_moveAnimDuration]. Retargeting mid-flight (a new
  // point arriving before the previous glide finished) starts from the
  // live interpolated position, not the old target — no backward snap.
  void _animateTo(LatLng target) {
    final from = _moveAnim?.value ?? target;
    _moveAnim = LatLngTween(begin: from, end: target).animate(
      CurvedAnimation(parent: _moveAnimCtrl, curve: Curves.easeInOut),
    );
    _moveAnimCtrl.forward(from: 0);
  }

  void _initMqtt(String collarSerial) {
    final mqtt = getIt<IMqttService>();
    _connectionStateSub = mqtt.connectionState.listen((connected) {
      if (!mounted) return;
      setState(() => _mqttConnected = connected);
      if (connected) _subscribeToTopics(mqtt);
    });
    mqtt.connect(collarSerial: collarSerial);
  }

  // Loads the dog's name and paired collar, then connects MQTT using that
  // collar's actual serial number — previously hardcoded to 'SIM001'
  // regardless of which dog/collar was really paired, so a second dog on a
  // different collar (e.g. SIM002) never received any live data. Also
  // seeds the map with the last known position from the backend if no
  // live MQTT position has arrived yet, so the screen shows "dernière
  // position il y a Xmin" instead of a contentless "waiting for signal"
  // the moment there's actually something to say.
  Future<void> _loadDogAndConnect() async {
    try {
      final dogs = await getIt<IDogRepository>().getDogs();
      if (dogs.isEmpty || !mounted) return;
      final dog = dogs.first;
      setState(() {
        _dogName = dog.name;
        _dogPhotoUrl = dog.photoUrl;
      });

      // getDogs() doesn't include the collar/geofence relations (only GET
      // /dogs/:dogId does) — fetch the full dog once for both.
      final full = await getIt<IDogRepository>().getDogById(dog.id);
      if (!mounted || full == null) return;
      setState(() => _geofenceZone = full.geofenceZone);

      final collarSerial = full.collar?.serialNumber;
      if (collarSerial != null) _initMqtt(collarSerial);

      if (_lastGps != null) return; // MQTT already delivered a live point
      final last = await getIt<IGpsRepository>().getLatestLocation(dog.id);
      if (last == null || !mounted || _lastGps != null) return;
      setState(() {
        _lastGps = _GpsPoint(
          lat: last.latitude,
          lng: last.longitude,
          accuracy: last.accuracy ?? 0,
          recordedAt: last.recordedAt,
        );
      });
      _snapTo(LatLng(last.latitude, last.longitude));
    } catch (_) {}
  }

  void _subscribeToTopics(IMqttService mqtt) {
    mqtt.subscribeToGps((topic, payload) {
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final point = _GpsPoint.fromJson(json);
        if (!mounted) return;

        final ll = LatLng(point.lat, point.lng);
        final previous = _lastGps;
        // No previous fix yet -> treat as real movement (first point seeds
        // via _snapTo below, not this path, but keep the check honest).
        final movedEnough =
            previous == null ||
            const Distance()(LatLng(previous.lat, previous.lng), ll) >=
                _noiseThresholdMeters;

        setState(() {
          _lastGps = point;

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
        });

        if (_moveAnim == null) {
          _snapTo(ll);
        } else if (movedEnough) {
          _animateTo(ll);
        }
        // else: GPS noise while stationary — leave marker/camera parked.
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
    if (_lastGps == null) return 'En attente du signal de $_dogName...';
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

  // ── Place search ──────────────────────────────────────────────────────────

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      // Empty search — nothing to look up, just clear any stale results.
      setState(() {
        _searchResults = [];
        _searchError = null;
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
      _showSearchResults = true;
    });

    try {
      final results = await getIt<IGeocodingService>().search(trimmed);
      if (!mounted) return;

      if (results.isEmpty) {
        setState(() {
          _searching = false;
          _searchResults = [];
          _searchError = 'Aucun lieu trouvé pour « $trimmed ».';
        });
        return;
      }

      if (results.length == 1) {
        _selectSearchResult(results.first);
        return;
      }

      setState(() {
        _searching = false;
        _searchResults = results;
      });
    } catch (e) {
      DebugLogger.log('MAP', 'Place search failed: $e');
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchResults = [];
        _searchError = 'Recherche indisponible — vérifie ta connexion.';
      });
    }
  }

  void _selectSearchResult(PlaceSearchResult result) {
    setState(() {
      _searching = false;
      _showSearchResults = false;
      _searchResults = [];
      _searchError = null;
      _followDog = false;
      _searchController.text = result.name;
    });
    _searchFocusNode.unfocus();
    _mapController.move(LatLng(result.latitude, result.longitude), 15);
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults = [];
      _searchError = null;
      _showSearchResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final savedTrails = ref.watch(trailListProvider);
    final topInset = MediaQuery.paddingOf(context).top;
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
                    onTap: (tapPosition, point) {
                      if (_showSearchResults) {
                        setState(() => _showSearchResults = false);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.k9sync',
                    ),
                    if (_geofenceZone != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: LatLng(
                              _geofenceZone!.latitude,
                              _geofenceZone!.longitude,
                            ),
                            radius: _geofenceZone!.radiusM.toDouble(),
                            useRadiusInMeter: true,
                            color: AppColors.orange.withValues(alpha: 0.15),
                            borderStrokeWidth: 2,
                            borderColor: AppColors.orange,
                          ),
                        ],
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
                    if (_lastGps != null && _moveAnim != null)
                      _AnimatedDogMarkerLayer(
                        animation: _moveAnim!,
                        live: _mqttConnected,
                        photoUrl: _dogPhotoUrl,
                      ),
                  ],
                ),

                // ── MQTT badge ─────────────────────────────────────────
                // top offset mirrors the search bar's below — both need the
                // status bar inset added, or this badge (and the follow
                // button below) render underneath the search row instead of
                // below it.
                Positioned(
                  top: topInset + 60,
                  left: 16,
                  child: LiveBadge(
                    connected: _mqttConnected,
                    liveLabel: 'MQTT • Live',
                    offlineLabel: 'MQTT • Off',
                  ),
                ),

                // ── Follow button ──────────────────────────────────────
                if (!_followDog)
                  Positioned(
                    top: topInset + 60,
                    right: 16,
                    child: Semantics(
                      button: true,
                      label: 'Recentrer la carte sur $_dogName',
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _followDog = true);
                          if (_lastGps != null) {
                            _animateTo(LatLng(_lastGps!.lat, _lastGps!.lng));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            border: Border.all(
                              color: AppColors.border,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [AppDimensions.cardShadowSm],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.my_location,
                                size: 14,
                                color: AppColors.orange,
                              ),
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
                  ),

                // ── Search bar ─────────────────────────────────────────
                // top offset includes the system status bar inset — this
                // row sits above the map with no SafeArea/AppBar of its
                // own, so a fixed top would land under the status bar and
                // never receive taps there.
                Positioned(
                  top: topInset + 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildSearchField()),
                          const SizedBox(width: 8),
                          _mapIconBtn(
                            Icons.history,
                            () => context.push('/home/carte/history'),
                            semanticLabel: 'Historique des balades',
                          ),
                          const SizedBox(width: 8),
                          _mapIconBtn(
                            Icons.pets,
                            () => context.push(AppRoutes.lostMode),
                            semanticLabel: 'Mode chien perdu',
                          ),
                        ],
                      ),
                      if (_showSearchResults) _buildSearchResultsPanel(),
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
                          label: Text(
                            savedTrails.isEmpty
                                ? 'Démarrer une balade'
                                : 'Nouvelle balade (${savedTrails.length} sauvegardée${savedTrails.length > 1 ? 's' : ''})',
                          ),
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
                        border: Border.all(color: AppColors.border, width: 2),
                        shape: BoxShape.circle,
                        boxShadow: [AppDimensions.cardShadowSm],
                      ),
                      child: resolvePhotoUrl(_dogPhotoUrl) != null
                          ? ClipOval(
                              child: Image.network(
                                resolvePhotoUrl(_dogPhotoUrl)!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Text(
                                    '🐕',
                                    style: TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                            )
                          : const Center(
                              child: Text('🐕', style: TextStyle(fontSize: 24)),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _dogName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
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

  Widget _mapIconBtn(
    IconData icon,
    VoidCallback onPressed, {
    required String semanticLabel,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
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
      ),
    );
  }

  Widget _buildSearchField() {
    return Semantics(
      textField: true,
      label: 'Rechercher un lieu sur la carte',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.border, width: 2),
          borderRadius: BorderRadius.circular(30),
          // No cardShadowSm here unlike elsewhere in the app — the
          // sticker-style offset shadow reads as a confusing double
          // outline against the map's busy tile background (streets,
          // colors) behind it. A single clean frame instead.
        ),
        child: Row(
          children: [
            Semantics(
              button: true,
              label: 'Lancer la recherche',
              child: GestureDetector(
                onTap: () => _performSearch(_searchController.text),
                child: Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: _performSearch,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  // The app's InputDecorationTheme sets enabledBorder and
                  // focusedBorder separately from border — Flutter paints
                  // those in preference to `border` when set, so leaving
                  // them unset here let the theme's own black rounded-rect
                  // outline show up inside this field's pill-shaped
                  // Container border. All three need to be none.
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  hintText: 'Rechercher un lieu...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
            if (_searching)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.orange,
                ),
              )
            else if (_searchController.text.isNotEmpty)
              Semantics(
                button: true,
                label: 'Effacer la recherche',
                child: GestureDetector(
                  onTap: _clearSearch,
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: AppDimensions.borderRadiusSm,
        boxShadow: [AppDimensions.cardShadowSm],
      ),
      child: _searchError != null
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                _searchError!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _searchResults.length,
              separatorBuilder: (_, _) =>
                  Container(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return Semantics(
                  button: true,
                  label: result.locality != null
                      ? 'Centrer la carte sur ${result.name}, ${result.locality}'
                      : 'Centrer la carte sur ${result.name}',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _selectSearchResult(result),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (result.locality != null)
                              Text(
                                result.locality!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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

// ── Extracted widgets ─────────────────────────────────────────────────────────

/// Linear interpolation between two [LatLng] — lets [TweenAnimationBuilder]
/// glide the marker smoothly to each new position instead of teleporting.
class LatLngTween extends Tween<LatLng> {
  LatLngTween({required super.begin, required super.end});

  @override
  LatLng lerp(double t) {
    final b = begin!;
    final e = end!;
    return LatLng(
      b.latitude + (e.latitude - b.latitude) * t,
      b.longitude + (e.longitude - b.longitude) * t,
    );
  }
}

/// Renders the dog marker at [animation]'s current value — the very same
/// [Animation] that also drives the "Suivre" camera pan (see
/// [_MapScreenState._onMoveTick]), so the marker glide and the camera pan
/// are always perfectly in sync instead of drifting apart.
class _AnimatedDogMarkerLayer extends StatelessWidget {
  final Animation<LatLng> animation;
  final bool live;
  final String? photoUrl;

  const _AnimatedDogMarkerLayer({
    required this.animation,
    required this.live,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return MarkerLayer(
          markers: [
            Marker(
              point: animation.value,
              width: 60,
              // 48 (avatar) + 3 (gap) + ~17 (status pill) = ~68px in theory,
              // but the pill's text line height varies a couple px with the
              // device's font metrics/text scale — 72 was tight enough to
              // overflow by 1px on some phones. Extra headroom here is
              // inert (Marker isn't clipped), just avoids the overflow.
              height: 76,
              child: child!,
            ),
          ],
        );
      },
      child: _DogMarker(live: live, photoUrl: photoUrl),
    );
  }
}

class _DogMarker extends StatelessWidget {
  final bool live;
  final String? photoUrl;
  const _DogMarker({required this.live, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = resolvePhotoUrl(photoUrl);
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
          child: resolvedUrl != null
              ? ClipOval(
                  child: Image.network(
                    resolvedUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text('🐕', style: TextStyle(fontSize: 26)),
                    ),
                  ),
                )
              : const Center(
                  child: Text('🐕', style: TextStyle(fontSize: 26)),
                ),
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
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
