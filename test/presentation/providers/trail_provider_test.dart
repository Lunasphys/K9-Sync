import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';

import 'package:k9sync/domain/entities/dog.dart';
import 'package:k9sync/domain/entities/trail.dart';
import 'package:k9sync/domain/entities/user.dart';
import 'package:k9sync/domain/enums/subscription_plan.dart';
import 'package:k9sync/domain/interfaces/repositories/i_auth_repository.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';
import 'package:k9sync/domain/interfaces/repositories/i_gps_repository.dart';
import 'package:k9sync/injection.dart';
import 'package:k9sync/presentation/providers/trail_provider.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

class MockDogRepository extends Mock implements IDogRepository {}

class MockGpsRepository extends Mock implements IGpsRepository {}

Trail _trail(String id, {List<LatLng> points = const [LatLng(1, 1)]}) {
  return Trail(
    id: id,
    startedAt: DateTime.utc(2026, 3, 14, 10, 0, 0),
    endedAt: DateTime.utc(2026, 3, 14, 10, 10, 0),
    points: points,
    distanceMeters: 500,
  );
}

void main() {
  late Directory tempDir;
  late MockAuthRepository mockAuth;
  late MockDogRepository mockDog;
  late MockGpsRepository mockGps;

  setUpAll(() {
    registerFallbackValue(_trail('fallback'));
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('trail_provider_test');
    Hive.init(tempDir.path);

    mockAuth = MockAuthRepository();
    mockDog = MockDogRepository();
    mockGps = MockGpsRepository();

    final now = DateTime.now();
    when(() => mockAuth.getCurrentUser()).thenAnswer(
      (_) async => User(
        id: 'user-1',
        email: 'test@test.com',
        firstName: 'Test',
        lastName: 'User',
        subscriptionPlan: SubscriptionPlan.free,
        createdAt: now,
        updatedAt: now,
      ),
    );
    when(() => mockDog.getDogs()).thenAnswer(
      (_) async => [
        Dog(id: 'dog-1', name: 'Bucky', createdAt: now, updatedAt: now),
      ],
    );

    if (getIt.isRegistered<IAuthRepository>()) {
      getIt.unregister<IAuthRepository>();
    }
    if (getIt.isRegistered<IDogRepository>()) {
      getIt.unregister<IDogRepository>();
    }
    if (getIt.isRegistered<IGpsRepository>()) {
      getIt.unregister<IGpsRepository>();
    }
    getIt.registerSingleton<IAuthRepository>(mockAuth);
    getIt.registerSingleton<IDogRepository>(mockDog);
    getIt.registerSingleton<IGpsRepository>(mockGps);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
    await getIt.reset();
  });

  group('TrailNotifier.addTrail', () {
    test(
      'creates the summary, then syncs points with the returned trailId',
      () async {
        when(
          () => mockGps.createTrail(any(), any()),
        ).thenAnswer((_) async => 'remote-trail-1');
        when(
          () => mockGps.syncOfflineLocations(
            any(),
            any(),
            trailId: any(named: 'trailId'),
          ),
        ).thenAnswer((_) async => 1);

        final notifier = TrailNotifier();
        await notifier.addTrail(_trail('local-1'));

        final captured = verify(
          () => mockGps.syncOfflineLocations(
            'dog-1',
            captureAny(),
            trailId: captureAny(named: 'trailId'),
          ),
        ).captured;
        expect(captured[1], 'remote-trail-1');
        expect(notifier.state.map((t) => t.id), contains('local-1'));
      },
    );

    test(
      'queues the trail for retry when the summary POST fails, '
      'without syncing points unlinked',
      () async {
        when(
          () => mockGps.createTrail(any(), any()),
        ).thenThrow(Exception('network down'));

        final notifier = TrailNotifier();
        await notifier.addTrail(_trail('local-2'));

        // Trail stays visible locally regardless of the backend failure.
        expect(notifier.state.map((t) => t.id), contains('local-2'));
        verifyNever(
          () => mockGps.syncOfflineLocations(
            any(),
            any(),
            trailId: any(named: 'trailId'),
          ),
        );
      },
    );
  });

  group('TrailNotifier.syncPendingTrails', () {
    test('retries a previously failed trail and clears it on success', () async {
      // First attempt fails and gets queued.
      when(
        () => mockGps.createTrail(any(), any()),
      ).thenThrow(Exception('network down'));
      final notifier = TrailNotifier();
      await notifier.addTrail(_trail('local-3'));

      // Network recovers — retry should succeed and stop being queued.
      when(
        () => mockGps.createTrail(any(), any()),
      ).thenAnswer((_) async => 'remote-trail-3');
      when(
        () => mockGps.syncOfflineLocations(
          any(),
          any(),
          trailId: any(named: 'trailId'),
        ),
      ).thenAnswer((_) async => 1);

      await notifier.syncPendingTrails();

      // Total createTrail calls so far: the failed attempt + the retry.
      verify(() => mockGps.createTrail('dog-1', any())).called(2);
      verify(
        () => mockGps.syncOfflineLocations(
          'dog-1',
          any(),
          trailId: 'remote-trail-3',
        ),
      ).called(1);

      // A second retry pass should be a no-op — nothing left pending.
      await notifier.syncPendingTrails();
      verifyNever(() => mockGps.createTrail(any(), any()));
    });
  });

  group('TrailNotifier.refreshFromRemote', () {
    test(
      'keeps the local (fully-pointed) version on id conflicts, adds '
      'remote-only trails, and keeps local-only trails',
      () async {
        when(
          () => mockGps.createTrail(any(), any()),
        ).thenAnswer((_) async => 'remote-shared');
        when(
          () => mockGps.syncOfflineLocations(
            any(),
            any(),
            trailId: any(named: 'trailId'),
          ),
        ).thenAnswer((_) async => 1);

        final notifier = TrailNotifier();
        // Synced trail — exists both locally (with points) and remotely.
        await notifier.addTrail(_trail('shared', points: const [LatLng(1, 1)]));
        // Local-only trail — summary POST failed, still pending.
        when(
          () => mockGps.createTrail(any(), any()),
        ).thenThrow(Exception('offline'));
        await notifier.addTrail(_trail('local-only'));

        when(() => mockGps.getTrails(any())).thenAnswer(
          (_) async => [
            Trail(
              id: 'shared',
              startedAt: DateTime.utc(2026, 3, 14, 10, 0, 0),
              endedAt: DateTime.utc(2026, 3, 14, 10, 10, 0),
              points: const [], // backend list endpoint has no polyline
              distanceMeters: 500,
            ),
            Trail(
              id: 'remote-only',
              startedAt: DateTime.utc(2026, 3, 15, 10, 0, 0),
              endedAt: DateTime.utc(2026, 3, 15, 10, 10, 0),
              points: const [],
              distanceMeters: 800,
            ),
          ],
        );

        await notifier.refreshFromRemote();

        final byId = {for (final t in notifier.state) t.id: t};
        expect(byId.keys, {'shared', 'local-only', 'remote-only'});
        // Local copy (with its GPS polyline) wins over the remote summary.
        expect(byId['shared']!.points, isNotEmpty);
        expect(byId['remote-only']!.points, isEmpty);
      },
    );
  });
}
