import 'package:equatable/equatable.dart';

/// Base class for failures in the domain/data layer (Clean Architecture).
abstract base class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Generic failure for server or unknown errors.
final class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server error']);
}

/// Failure when a requested resource is not found.
final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Not found']);
}
