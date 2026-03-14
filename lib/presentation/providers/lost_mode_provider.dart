import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:k9sync/core/debug/debug_logger.dart';
import 'package:k9sync/domain/interfaces/services/i_mqtt_service.dart';
import 'package:k9sync/injection.dart';

/// Global lost mode state — shared between LostModeScreen, main shell badge,
/// and AlertsScreen banner.
final lostModeProvider =
    StateNotifierProvider<LostModeNotifier, bool>((ref) => LostModeNotifier());

class LostModeNotifier extends StateNotifier<bool> {
  static const _collarSerial = 'SIM001';

  LostModeNotifier() : super(false);

  Future<void> activate() => _set(true);
  Future<void> deactivate() => _set(false);
  Future<void> toggle() => state ? deactivate() : activate();

  Future<void> _set(bool active) async {
    try {
      await getIt<IMqttService>().publishLostMode(
        _collarSerial,
        active: active,
      );
      state = active;
      DebugLogger.collar(
        'Lost mode ${active ? "activated" : "deactivated"}',
      );
    } catch (e) {
      DebugLogger.collar('Lost mode publish failed: $e');
      // Do not update state if publish failed
    }
  }
}

