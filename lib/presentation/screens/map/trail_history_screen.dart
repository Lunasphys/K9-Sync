import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/entities/trail.dart';
import 'package:k9sync/presentation/providers/trail_provider.dart';

class TrailHistoryScreen extends ConsumerWidget {
  const TrailHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trails = ref.watch(trailListProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Historique des balades',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.border),
        ),
      ),
      body: trails.isEmpty
          ? _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: trails.length,
              // Most recent first
              itemBuilder: (context, index) {
                final trail = trails[trails.length - 1 - index];
                return _TrailCard(trail: trail);
              },
            ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🐾', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            'Aucune balade enregistrée',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Lance une balade depuis la carte\npour la voir apparaître ici.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trail card ────────────────────────────────────────────────────────────────

class _TrailCard extends StatelessWidget {
  final Trail trail;

  const _TrailCard({required this.trail});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showTrailDetail(context, trail),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.border, width: 2),
          borderRadius: AppDimensions.borderRadius,
          boxShadow: [AppDimensions.cardShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mini map preview
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radius - 2),
              ),
              child: SizedBox(
                height: 140,
                child: _TrailMiniMap(trail: trail),
              ),
            ),
            Container(height: 2, color: AppColors.border),
            // Stats row
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatDate(trail.startedAt),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      _tag('🐕 Bucky'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _stat(
                        '${(trail.distanceMeters / 1000).toStringAsFixed(2)} km',
                        'Distance',
                        Icons.straighten,
                      ),
                      const SizedBox(width: 10),
                      _stat(
                        _formatDuration(trail.duration),
                        'Durée',
                        Icons.timer_outlined,
                      ),
                      const SizedBox(width: 10),
                      _stat(
                        '${trail.points.length}',
                        'Points GPS',
                        Icons.location_on_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border, width: 2),
          borderRadius: AppDimensions.borderRadiusSm,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.orange),
            const SizedBox(width: 5),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900)),
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.cream,
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
      'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} · ${h}h$m';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h${d.inMinutes.remainder(60).toString().padLeft(2, '0')}';
    return '${d.inMinutes}min${d.inSeconds.remainder(60).toString().padLeft(2, '0')}s';
  }

  void _showTrailDetail(BuildContext context, Trail trail) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrailDetailSheet(trail: trail),
    );
  }
}

// ── Mini map (non-interactive) ────────────────────────────────────────────────

class _TrailMiniMap extends StatelessWidget {
  final Trail trail;
  const _TrailMiniMap({required this.trail});

  @override
  Widget build(BuildContext context) {
    if (trail.points.isEmpty) {
      return Container(color: AppColors.bg);
    }

    // Compute bounds center for initial camera
    double minLat = trail.points.first.latitude;
    double maxLat = trail.points.first.latitude;
    double minLng = trail.points.first.longitude;
    double maxLng = trail.points.first.longitude;

    for (final p in trail.points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    return IgnorePointer(
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 15,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.k9sync',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: trail.points,
                color: AppColors.orange,
                strokeWidth: 3.5,
              ),
            ],
          ),
          // Start marker (green dot)
          MarkerLayer(
            markers: [
              Marker(
                point: trail.points.first,
                width: 14,
                height: 14,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.greenStatus,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
              // End marker (red dot)
              Marker(
                point: trail.points.last,
                width: 14,
                height: 14,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Detail bottom sheet ───────────────────────────────────────────────────────

class _TrailDetailSheet extends StatelessWidget {
  final Trail trail;
  const _TrailDetailSheet({required this.trail});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  _formatDate(trail.startedAt),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Container(height: 2, color: AppColors.border),
          // Full-size map
          Expanded(
            child: trail.points.isEmpty
                ? const Center(child: Text('Pas de points GPS'))
                : _TrailMiniMap(trail: trail),
          ),
          Container(height: 2, color: AppColors.border),
          // Stats
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _bigStat(
                  '${(trail.distanceMeters / 1000).toStringAsFixed(2)} km',
                  'Distance',
                ),
                _divider(),
                _bigStat(
                  _formatDuration(trail.duration),
                  'Durée',
                ),
                _divider(),
                _bigStat(
                  '${trail.points.length}',
                  'Points GPS',
                ),
                _divider(),
                _bigStat(
                  '${_avgSpeed(trail)} km/h',
                  'Vitesse moy.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _divider() {
    return Container(
        width: 2, height: 36, color: AppColors.border);
  }

  String _formatDate(DateTime dt) {
    const months = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
      'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} · ${h}h$m';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h${d.inMinutes.remainder(60).toString().padLeft(2, '0')}';
    return '${d.inMinutes}min';
  }

  String _avgSpeed(Trail t) {
    if (t.duration.inSeconds == 0) return '–';
    final kmh = (t.distanceMeters / 1000) /
        (t.duration.inSeconds / 3600);
    return kmh.toStringAsFixed(1);
  }
}
