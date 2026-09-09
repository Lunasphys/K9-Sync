import '../constants/api_constants.dart';

/// Resolves a possibly-relative photo URL (POST /upload/dog-photo returns
/// e.g. "/uploads/dog_123.jpg", not an absolute URL) into one Image.network
/// can actually load. Already-absolute URLs are returned unchanged. Null or
/// empty input returns null, so callers can use the result directly as an
/// "is there a photo" check.
String? resolvePhotoUrl(String? photoUrl) {
  if (photoUrl == null || photoUrl.isEmpty) return null;
  if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
    return photoUrl;
  }
  final origin = Uri.parse(ApiConstants.baseUrl).origin;
  return '$origin$photoUrl';
}
