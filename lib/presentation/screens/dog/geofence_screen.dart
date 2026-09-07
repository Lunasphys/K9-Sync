import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:k9sync/core/constants/app_constants.dart';
import 'package:k9sync/core/errors/app_error.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';
import 'package:k9sync/domain/interfaces/repositories/i_gps_repository.dart';
import 'package:k9sync/injection.dart';

const double _defaultRadiusM = 100;
const double _maxRadiusM = 2000;
const LatLng _fallbackCenter = LatLng(45.7578, 4.8320);

/// Définition de la zone de sécurité (geofence) — un seul cercle par chien.
/// Centre placé en tapant la carte (préseedé sur la dernière position connue
/// du chien s'il y en a une), rayon ajusté au slider, sauvegarde en upsert
/// (PUT /dogs/:dogId/geofence). Suppression si une zone existe déjà.
class GeofenceScreen extends StatefulWidget {
  const GeofenceScreen({super.key, this.dogId});
  final String? dogId;

  @override
  State<GeofenceScreen> createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends State<GeofenceScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  String? _error;
  String _dogName = 'mon chien';
  bool _hadExistingZone = false;

  LatLng? _center;
  double _radiusM = _defaultRadiusM;

  final _mapController = MapController();

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
      if (dog == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Chien introuvable.';
        });
        return;
      }

      final zone = dog.geofenceZone;
      if (zone != null) {
        _center = LatLng(zone.latitude, zone.longitude);
        _radiusM = zone.radiusM.toDouble().clamp(
          AppConstants.geofenceRadiusMinM.toDouble(),
          _maxRadiusM,
        );
        _hadExistingZone = true;
      } else {
        // No zone yet — seed the center on the dog's last known position so
        // there's something sensible to adjust rather than an empty map.
        final last = await getIt<IGpsRepository>().getLatestLocation(dogId);
        if (last != null) _center = LatLng(last.latitude, last.longitude);
      }

      if (!mounted) return;
      setState(() {
        _dogName = dog.name;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is AppError
            ? (e.userMessage ?? 'Impossible de charger la zone.')
            : 'Impossible de charger la zone.';
      });
    }
  }

  Future<void> _save() async {
    final dogId = widget.dogId;
    final center = _center;
    if (dogId == null || center == null || _saving) return;

    setState(() => _saving = true);
    try {
      await getIt<IDogRepository>().upsertGeofence(
        dogId,
        latitude: center.latitude,
        longitude: center.longitude,
        radiusM: _radiusM.round(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Zone de sécurité enregistrée.')));
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      final message = e is AppError
          ? (e.userMessage ?? 'Échec de l\'enregistrement de la zone.')
          : 'Échec de l\'enregistrement de la zone.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final dogId = widget.dogId;
    if (dogId == null || _deleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border, width: 2),
        ),
        title: const Text(
          'Supprimer la zone ?',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        content: Text(
          'Vous ne recevrez plus d\'alerte si $_dogName quitte cette zone.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Annuler',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.redDanger,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await getIt<IDogRepository>().deleteGeofence(dogId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Zone de sécurité supprimée.')));
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      final message = e is AppError
          ? (e.userMessage ?? 'Échec de la suppression de la zone.')
          : 'Échec de la suppression de la zone.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Zone de sécurité')),
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            _center == null
                ? 'Touchez la carte pour placer le centre de la zone.'
                : 'Touchez la carte pour déplacer le centre de la zone.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _center ?? _fallbackCenter,
                  initialZoom: 16,
                  onTap: (tapPosition, point) =>
                      setState(() => _center = point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.k9sync',
                  ),
                  if (_center != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _center!,
                          radius: _radiusM,
                          useRadiusInMeter: true,
                          color: AppColors.orange.withValues(alpha: 0.2),
                          borderStrokeWidth: 2,
                          borderColor: AppColors.orange,
                        ),
                      ],
                    ),
                  if (_center != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _center!,
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.orange,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.border,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border(top: BorderSide(color: AppColors.border, width: 2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RAYON',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    '${_radiusM.round()} m',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.orange,
                  inactiveTrackColor: AppColors.border,
                  thumbColor: AppColors.orange,
                  overlayColor: AppColors.orange.withValues(alpha: 0.15),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _radiusM,
                  min: AppConstants.geofenceRadiusMinM.toDouble(),
                  max: _maxRadiusM,
                  divisions: (_maxRadiusM - AppConstants.geofenceRadiusMinM).round(),
                  semanticFormatterCallback: (v) => '${v.round()} mètres',
                  onChanged: (v) => setState(() => _radiusM = v),
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                button: true,
                enabled: _center != null && !_saving,
                label: _saving
                    ? 'Enregistrement de la zone en cours'
                    : (_center != null
                          ? 'Enregistrer la zone de sécurité, rayon ${_radiusM.round()} mètres'
                          : 'Enregistrer — indisponible tant qu\'aucun centre '
                                'n\'est placé sur la carte'),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_center != null && !_saving) ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text('Enregistrer la zone'),
                  ),
                ),
              ),
              if (_hadExistingZone) ...[
                const SizedBox(height: 8),
                Semantics(
                  button: true,
                  enabled: !_deleting,
                  label: _deleting
                      ? 'Suppression de la zone en cours'
                      : 'Supprimer la zone de sécurité',
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _deleting ? null : _delete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.redDanger,
                        side: BorderSide(color: AppColors.redDanger, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _deleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Supprimer la zone'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
