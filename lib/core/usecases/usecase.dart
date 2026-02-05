import '../errors/failures.dart';

/// Base use case contract (Clean Architecture).
/// [Type] is the return type, [Params] is the input (use [void] or [NoParams] if none).
abstract interface class UseCase<Type, Params> {
  Future<Type> call(Params params);
}

/// Use when a use case has no parameters.
final class NoParams {
  const NoParams();
}

/// Helper for use cases that can fail (return Either<Failure, T>).
/// Add a package like dartz or fpdart for Either if you use this.
typedef Result<T> = ({Failure? failure, T? data});
