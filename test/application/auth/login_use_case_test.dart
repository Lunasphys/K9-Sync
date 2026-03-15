import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:k9sync/application/auth/login_use_case.dart';
import 'package:k9sync/core/errors/auth_error.dart';
import 'package:k9sync/domain/entities/user.dart';
import 'package:k9sync/domain/enums/subscription_plan.dart';
import 'package:k9sync/domain/interfaces/repositories/i_auth_repository.dart';

// Mock implementation of IAuthRepository
class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late MockAuthRepository mockRepo;
  late LoginUseCase loginUseCase;

  setUp(() {
    mockRepo = MockAuthRepository();
    loginUseCase = LoginUseCase(mockRepo);
  });

  group('LoginUseCase', () {
    const validEmail = 'test@test.com';
    const validPassword = 'Test1234!';

    final now = DateTime.now();
    final fakeUser = User(
      id: 'user-123',
      email: validEmail,
      firstName: 'Test',
      lastName: 'User',
      subscriptionPlan: SubscriptionPlan.free,
      createdAt: now,
      updatedAt: now,
    );

    final fakeResult = AuthResult(
      user: fakeUser,
      accessToken: 'access_token_fake',
      refreshToken: 'refresh_token_fake',
    );

    test('returns AuthResult when credentials are valid', () async {
      // Arrange
      when(() => mockRepo.login(
            email: validEmail,
            password: validPassword,
          )).thenAnswer((_) async => fakeResult);

      // Act
      final result = await loginUseCase(
        email: validEmail,
        password: validPassword,
      );

      // Assert
      expect(result.accessToken, equals('access_token_fake'));
      expect(result.user.email, equals(validEmail));
      verify(() => mockRepo.login(
            email: validEmail,
            password: validPassword,
          )).called(1);
    });

    test('throws AuthError when credentials are invalid', () async {
      // Arrange
      when(() => mockRepo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(const AuthError.invalidCredentials());

      // Act & Assert
      expect(
        () => loginUseCase(email: 'wrong@test.com', password: 'wrong'),
        throwsA(isA<AuthError>()),
      );
    });

    test('calls repository exactly once per login attempt', () async {
      // Arrange
      when(() => mockRepo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => fakeResult);

      // Act
      await loginUseCase(email: validEmail, password: validPassword);

      // Assert — repository called exactly once, not cached or duplicated
      verify(() => mockRepo.login(
            email: validEmail,
            password: validPassword,
          )).called(1);
    });
  });
}
