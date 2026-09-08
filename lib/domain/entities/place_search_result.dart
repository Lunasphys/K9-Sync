/// A single geocoding match — a place name plus the locality (city/country)
/// that disambiguates it from same-named places elsewhere.
class PlaceSearchResult {
  final String name;
  final String? locality;
  final double latitude;
  final double longitude;

  const PlaceSearchResult({
    required this.name,
    this.locality,
    required this.latitude,
    required this.longitude,
  });

  /// Parses one entry of a Nominatim `/search?format=jsonv2&addressdetails=1`
  /// response. Returns null if [json] carries no usable coordinates.
  static PlaceSearchResult? fromNominatimJson(Map<String, dynamic> json) {
    final lat = double.tryParse(json['lat']?.toString() ?? '');
    final lon = double.tryParse(json['lon']?.toString() ?? '');
    if (lat == null || lon == null) return null;

    // jsonv2 usually carries a distinct `name` (e.g. a POI's actual name,
    // more precise than guessing from display_name) — fall back to the
    // first display_name segment for results that don't have one (broader
    // administrative areas, etc).
    final rawName = json['name'] as String?;
    final displayName = json['display_name'] as String? ?? '';
    final firstSegment = displayName.split(',').first.trim();
    final name = rawName != null && rawName.trim().isNotEmpty
        ? rawName.trim()
        : (firstSegment.isNotEmpty ? firstSegment : displayName);

    final address = json['address'] as Map<String, dynamic>?;
    final city =
        address?['city'] ??
        address?['town'] ??
        address?['village'] ??
        address?['municipality'] ??
        address?['county'];
    final country = address?['country'];
    final localityParts = [
      city,
      country,
    ].whereType<String>().where((s) => s.isNotEmpty).toList();

    return PlaceSearchResult(
      name: name,
      locality: localityParts.isEmpty ? null : localityParts.join(', '),
      latitude: lat,
      longitude: lon,
    );
  }
}
