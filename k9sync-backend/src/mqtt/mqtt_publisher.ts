import { getMqttClient } from './mqtt_client.js';
import { logger } from '../shared/logger.js';

export interface AlertMqttPayload {
  type: string;
  message: string;
  severity: string;
}

/**
 * Exported as an object (not a bare function), same reasoning as
 * pushNotifications: tests can swap the method with
 * `t.mock.method(mqttPublisher, 'publishAlert', ...)` without needing a live
 * broker connection.
 *
 * Republishes a server-detected event (geofence exit — the app's collar
 * itself never sees this) onto the same k9sync/collar/{serial}/alert topic
 * the collar/simulator uses for its own anomalies, so AlertsBloc's single
 * live subscription picks it up the same way regardless of who published it.
 * Never throws — a publish failure must not break the flow that triggered it.
 */
export const mqttPublisher = {
  publishAlert(serial: string, alert: AlertMqttPayload): void {
    const client = getMqttClient();
    if (!client) return; // no live broker (e.g. tests, or not connected yet)

    const payload = JSON.stringify({ ...alert, triggeredAt: new Date().toISOString() });
    try {
      client.publish(`k9sync/collar/${serial}/alert`, payload, { qos: 1 }, (err) => {
        if (err) logger.warn({ err, serial }, 'MQTT alert publish failed (non-fatal)');
      });
    } catch (err) {
      logger.warn({ err, serial }, 'MQTT alert publish failed (non-fatal)');
    }
  },
};
