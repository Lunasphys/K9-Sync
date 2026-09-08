import 'package:flutter_test/flutter_test.dart';
import 'package:k9sync/domain/entities/place_search_result.dart';

void main() {
  group('PlaceSearchResult.fromNominatimJson', () {
    test('prefers the explicit name field when present', () {
      final json = {
        'lat': '45.7578137',
        'lon': '4.8320114',
        'name': 'Place Bellecour',
        'display_name':
            'Place Bellecour, Bellecour, Lyon 2e Arrondissement, Lyon, '
            'Métropole de Lyon, Rhône, Auvergne-Rhône-Alpes, France',
        'address': {
          'city': 'Lyon',
          'country': 'France',
        },
      };

      final result = PlaceSearchResult.fromNominatimJson(json);

      expect(result, isNotNull);
      expect(result!.name, 'Place Bellecour');
      expect(result.locality, 'Lyon, France');
      expect(result.latitude, closeTo(45.7578137, 0.0000001));
      expect(result.longitude, closeTo(4.8320114, 0.0000001));
    });

    test('falls back to the first display_name segment when name is absent', () {
      final json = {
        'lat': '45.7578137',
        'lon': '4.8320114',
        'display_name':
            'Place Bellecour, Bellecour, Lyon 2e Arrondissement, Lyon, France',
        'address': {'city': 'Lyon', 'country': 'France'},
      };

      final result = PlaceSearchResult.fromNominatimJson(json);

      expect(result!.name, 'Place Bellecour');
    });

    test('falls back to town/village/municipality/county when city is absent', () {
      final json = {
        'lat': '48.0',
        'lon': '2.0',
        'display_name': 'Petit Village, France',
        'address': {'village': 'Petit Village', 'country': 'France'},
      };

      final result = PlaceSearchResult.fromNominatimJson(json);

      expect(result!.locality, 'Petit Village, France');
    });

    test('locality is null when address has neither locality nor country', () {
      final json = {
        'lat': '48.0',
        'lon': '2.0',
        'display_name': 'Somewhere',
        'address': <String, dynamic>{},
      };

      final result = PlaceSearchResult.fromNominatimJson(json);

      expect(result!.locality, isNull);
    });

    test('falls back to the full display_name when it has no comma', () {
      final json = {
        'lat': '48.0',
        'lon': '2.0',
        'display_name': 'Paris',
      };

      final result = PlaceSearchResult.fromNominatimJson(json);

      expect(result!.name, 'Paris');
    });

    test('returns null when lat/lon are missing or unparsable', () {
      expect(
        PlaceSearchResult.fromNominatimJson({'display_name': 'Nowhere'}),
        isNull,
      );
      expect(
        PlaceSearchResult.fromNominatimJson({
          'lat': 'not-a-number',
          'lon': '2.0',
          'display_name': 'Nowhere',
        }),
        isNull,
      );
    });
  });
}
