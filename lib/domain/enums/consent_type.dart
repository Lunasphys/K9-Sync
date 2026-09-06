/// Consent type (RGPD). Values match the backend's ConsentLog.type strings exactly.
enum ConsentType {
  termsOfService('terms_of_service'),
  gpsDataCollection('gps_data_collection'),
  healthDataCollection('health_data_collection');

  final String value;
  const ConsentType(this.value);
}
