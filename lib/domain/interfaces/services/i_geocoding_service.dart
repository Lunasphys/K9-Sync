import '../../entities/place_search_result.dart';

/// Contract for place-name search (Clean Architecture — domain).
abstract interface class IGeocodingService {
  /// Returns matches for [query], most relevant first. Empty list if
  /// nothing matched. Throws on network/server failure.
  Future<List<PlaceSearchResult>> search(String query);
}
