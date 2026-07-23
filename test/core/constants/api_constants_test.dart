import 'package:flutter_test/flutter_test.dart';
import 'package:k9sync/core/constants/api_constants.dart';

void main() {
  group('ApiConstants dog endpoints', () {
    test('dogById builds the correct path', () {
      expect(ApiConstants.dogById('abc-123'), '/dogs/abc-123');
    });

    test('dogUsers builds the correct path', () {
      expect(ApiConstants.dogUsers('abc-123'), '/dogs/abc-123/users');
    });

    test('dogInvite builds the correct path', () {
      expect(ApiConstants.dogInvite('abc-123'), '/dogs/abc-123/invite');
    });

    test('dogRemoveUser interpolates both the dog and user ids in order', () {
      expect(
        ApiConstants.dogRemoveUser('dog-1', 'user-2'),
        '/dogs/dog-1/users/user-2',
      );
    });
  });

  group('ApiConstants collar endpoints', () {
    test('collarById builds the correct path', () {
      expect(ApiConstants.collarById('SIM001'), '/collars/SIM001');
    });

    test('collarStatus builds the correct path', () {
      expect(ApiConstants.collarStatus('SIM001'), '/collars/SIM001/status');
    });

    test('collarLostMode builds the correct path', () {
      expect(
        ApiConstants.collarLostMode('SIM001'),
        '/collars/SIM001/lost-mode',
      );
    });
  });

  group('ApiConstants GPS endpoints', () {
    test('gpsLatest is nested under the dog', () {
      expect(ApiConstants.gpsLatest('dog-1'), '/dogs/dog-1/gps/latest');
    });

    test('gpsHistory is nested under the dog', () {
      expect(ApiConstants.gpsHistory('dog-1'), '/dogs/dog-1/gps/history');
    });

    test('gpsTrailById interpolates both the dog and trail ids', () {
      expect(
        ApiConstants.gpsTrailById('dog-1', 'trail-7'),
        '/dogs/dog-1/gps/trails/trail-7',
      );
    });

    test('gpsSync is nested under the dog', () {
      expect(ApiConstants.gpsSync('dog-1'), '/dogs/dog-1/gps/sync');
    });
  });

  group('ApiConstants health endpoints', () {
    test('healthLatest is nested under the dog', () {
      expect(ApiConstants.healthLatest('dog-1'), '/dogs/dog-1/health/latest');
    });

    test('healthAnomalies is nested under the dog', () {
      expect(
        ApiConstants.healthAnomalies('dog-1'),
        '/dogs/dog-1/health/anomalies',
      );
    });

    test('healthExport is nested under the dog', () {
      expect(ApiConstants.healthExport('dog-1'), '/dogs/dog-1/health/export');
    });
  });

  group('ApiConstants alert endpoints', () {
    test('alertById interpolates both the dog and alert ids', () {
      expect(
        ApiConstants.alertById('dog-1', 'alert-9'),
        '/dogs/dog-1/alerts/alert-9',
      );
    });

    test('alertRead builds the mark-as-read path', () {
      expect(
        ApiConstants.alertRead('dog-1', 'alert-9'),
        '/dogs/dog-1/alerts/alert-9/read',
      );
    });

    test('alertsReadAll is nested under the dog, without an alert id', () {
      expect(
        ApiConstants.alertsReadAll('dog-1'),
        '/dogs/dog-1/alerts/read-all',
      );
    });
  });

  group('ApiConstants static paths', () {
    test('user constants are fixed, dog-independent paths', () {
      expect(ApiConstants.userMe, '/users/me');
      expect(ApiConstants.userPushToken, '/users/me/push-token');
      expect(ApiConstants.userSubscription, '/users/me/subscription');
    });

    test('auth constants are fixed paths', () {
      expect(ApiConstants.authLogin, '/auth/login');
      expect(ApiConstants.authRegister, '/auth/register');
      expect(ApiConstants.authRefresh, '/auth/refresh');
    });
  });
}
