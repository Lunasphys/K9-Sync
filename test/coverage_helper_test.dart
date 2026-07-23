// Coverage measurement helper — imports every file in domain/application/core
// so `flutter test --coverage` reports a real 0% for untested files instead
// of omitting them from lcov.info entirely. No logic here, nothing to test.
// ignore_for_file: unused_import

import 'package:flutter_test/flutter_test.dart';

import 'package:k9sync/application/alert/get_alerts_use_case.dart';
import 'package:k9sync/application/alert/mark_alert_read_use_case.dart';
import 'package:k9sync/application/alert/send_notification_use_case.dart';
import 'package:k9sync/application/alert/trigger_lost_mode_use_case.dart';
import 'package:k9sync/application/auth/get_current_user_use_case.dart';
import 'package:k9sync/application/auth/login_use_case.dart';
import 'package:k9sync/application/auth/logout_use_case.dart';
import 'package:k9sync/application/auth/refresh_token_use_case.dart';
import 'package:k9sync/application/auth/register_use_case.dart';
import 'package:k9sync/application/dog/create_dog_use_case.dart';
import 'package:k9sync/application/dog/get_dog_profile_use_case.dart';
import 'package:k9sync/application/dog/invite_user_to_collar_use_case.dart';
import 'package:k9sync/application/dog/update_dog_use_case.dart';
import 'package:k9sync/application/gps/get_location_history_use_case.dart';
import 'package:k9sync/application/gps/get_realtime_location_use_case.dart';
import 'package:k9sync/application/gps/sync_offline_data_use_case.dart';
import 'package:k9sync/application/health/detect_anomaly_use_case.dart';
import 'package:k9sync/application/health/get_health_records_use_case.dart';
import 'package:k9sync/application/health/get_sleep_analysis_use_case.dart';
import 'package:k9sync/application/health/sync_offline_health_use_case.dart';

import 'package:k9sync/core/constants/api_constants.dart';
import 'package:k9sync/core/constants/app_constants.dart';
import 'package:k9sync/core/constants/firebase_constants.dart';
import 'package:k9sync/core/constants/storage_keys.dart';
import 'package:k9sync/core/debug/debug_logger.dart';
import 'package:k9sync/core/errors/app_error.dart';
import 'package:k9sync/core/errors/auth_error.dart';
import 'package:k9sync/core/errors/business_error.dart';
import 'package:k9sync/core/errors/collar_error.dart';
import 'package:k9sync/core/errors/failures.dart';
import 'package:k9sync/core/errors/gps_error.dart';
import 'package:k9sync/core/errors/health_error.dart';
import 'package:k9sync/core/errors/network_error.dart';
import 'package:k9sync/core/errors/storage_error.dart';
import 'package:k9sync/core/extensions/datetime_ext.dart';
import 'package:k9sync/core/extensions/string_ext.dart';
import 'package:k9sync/core/usecases/usecase.dart';
import 'package:k9sync/core/utils/gps_utils.dart';
import 'package:k9sync/core/utils/health_utils.dart';

import 'package:k9sync/domain/entities/activity_record.dart';
import 'package:k9sync/domain/entities/alert.dart';
import 'package:k9sync/domain/entities/collar.dart';
import 'package:k9sync/domain/entities/dog.dart';
import 'package:k9sync/domain/entities/gps_location.dart';
import 'package:k9sync/domain/entities/health_record.dart';
import 'package:k9sync/domain/entities/trail.dart';
import 'package:k9sync/domain/entities/user.dart';
import 'package:k9sync/domain/enums/alert_type.dart';
import 'package:k9sync/domain/enums/anomaly_type.dart';
import 'package:k9sync/domain/enums/notification_priority.dart';
import 'package:k9sync/domain/enums/sleep_phase.dart';
import 'package:k9sync/domain/enums/subscription_plan.dart';
import 'package:k9sync/domain/enums/user_dog_role.dart';
import 'package:k9sync/domain/interfaces/repositories/i_alert_repository.dart';
import 'package:k9sync/domain/interfaces/repositories/i_auth_repository.dart';
import 'package:k9sync/domain/interfaces/repositories/i_collar_repository.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';
import 'package:k9sync/domain/interfaces/repositories/i_gps_repository.dart';
import 'package:k9sync/domain/interfaces/repositories/i_health_repository.dart';
import 'package:k9sync/domain/interfaces/services/i_health_data_service.dart';
import 'package:k9sync/domain/interfaces/services/i_location_service.dart';
import 'package:k9sync/domain/interfaces/services/i_mqtt_service.dart';
import 'package:k9sync/domain/interfaces/services/i_notification_service.dart';
import 'package:k9sync/domain/models/notification_payload.dart';

void main() {
  test('coverage helper loads without error', () {
    expect(true, isTrue);
  });
}
