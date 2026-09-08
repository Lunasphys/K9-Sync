import 'package:dio/dio.dart';

import '../../domain/entities/place_search_result.dart';
import '../../domain/interfaces/services/i_geocoding_service.dart';

/// Geocoding via l'API Nominatim (OpenStreetMap) — gratuite, sans clé, déjà
/// cohérente avec les tuiles OSM utilisées ailleurs dans l'app. Sa politique
/// d'usage (operations.osmfoundation.org/policies/nominatim) impose un
/// User-Agent identifiable et une limite d'1 requête/seconde ; les deux sont
/// respectées ici plutôt que renvoyées à la charge de l'appelant.
///
/// Utilise volontairement un [Dio] tout neuf, jamais celui de [getIt]/DI :
/// ce dernier porte l'intercepteur qui attache notre token d'accès à chaque
/// requête — l'envoyer à un serveur tiers serait une fuite de credentials.
class NominatimGeocodingService implements IGeocodingService {
  NominatimGeocodingService() : _dio = Dio();

  final Dio _dio;

  static DateTime? _lastRequestAt;
  static const _minInterval = Duration(seconds: 1);

  @override
  Future<List<PlaceSearchResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    await _respectRateLimit();

    final response = await _dio.get<List<dynamic>>(
      'https://nominatim.openstreetmap.org/search',
      queryParameters: {
        'q': trimmed,
        'format': 'jsonv2',
        'addressdetails': 1,
        'limit': 8,
      },
      options: Options(
        headers: {
          // Identifiable comme demandé par la politique d'usage — pas
          // d'appel anonyme à leur infra.
          'User-Agent': 'K9Sync/1.0 (contact: support@k9sync.app)',
        },
      ),
    );

    final list = response.data ?? [];
    return list
        .map(
          (e) => PlaceSearchResult.fromNominatimJson(e as Map<String, dynamic>),
        )
        .whereType<PlaceSearchResult>()
        .toList();
  }

  /// Espace les appels d'au moins 1s, tous appelants confondus (compteur
  /// statique) — la limite est par IP/service côté Nominatim, pas par écran.
  Future<void> _respectRateLimit() async {
    final last = _lastRequestAt;
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < _minInterval) {
        await Future.delayed(_minInterval - elapsed);
      }
    }
    _lastRequestAt = DateTime.now();
  }
}
