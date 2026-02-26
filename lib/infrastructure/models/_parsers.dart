// Parsers partagés pour fromJson — alignés sur le backend Prisma (camelCase, Decimal en String).

/// Parse un DateTime depuis une string ISO ou null.
DateTime? parseDateTime(dynamic v) =>
    v == null ? null : DateTime.tryParse(v as String);

/// Parse un DateTime non-nullable (lève si absent).
DateTime parseDateTimeRequired(dynamic v) =>
    DateTime.parse((v ?? '') as String);

/// Parse un double depuis String Prisma Decimal ('38.50') ou num.
double? parseDecimal(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

/// Parse un int nullable (SMALLINT Postgres peut arriver comme int ou String). 
int? parseInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is String) return int.tryParse(v);
  return null;
}

/// Parse un [List] de String depuis un tableau JSON ou null.
List<String> parseStringList(dynamic v) {
  if (v == null) return [];
  return (v as List).map((e) => e as String).toList();
}
