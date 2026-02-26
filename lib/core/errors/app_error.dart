/// Base app error (Clean Architecture — domain). All domain/API errors extend this.
abstract class AppError implements Exception {
  final String code;
  final String message;
  final String? userMessage;
  final Object? cause;
  final Map<String, dynamic>? context;

  const AppError({
    required this.code,
    required this.message,
    this.userMessage,
    this.cause,
    this.context,
  });

  @override
  String toString() => '[$code] $message ${context ?? ''}';
}
