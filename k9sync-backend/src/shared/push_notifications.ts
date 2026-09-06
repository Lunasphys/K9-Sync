import { getPrisma } from '../config/database.js';
import { getMessaging } from '../config/firebase.js';
import { logger } from './logger.js';

export interface AlertPushPayload {
  title: string;
  body?: string;
  data?: Record<string, string>;
}

/**
 * Exported as an object (not a bare function) so tests can swap the method
 * with `t.mock.method(pushNotifications, 'notifyDogAccessHolders', ...)`
 * without needing to mock the Firebase SDK itself.
 *
 * Never throws — a push failure must never break the alert-creation flow
 * that triggered it (health sync, activity sync, MQTT ingestion, ...).
 *
 * NOT wired to lost-mode or geofence-exit: as of this commit neither one
 * creates a server-side event to hang a push off of. Lost mode is a direct
 * phone -> MQTT broker -> collar publish (see mqtt_service.dart), with no
 * backend involvement at all; geofencing doesn't exist yet (no zones model,
 * no exit detection). Wiring those requires building that server-side event
 * first — this module only reacts to alerts that actually get created today.
 */
export const pushNotifications = {
  async notifyDogAccessHolders(dogId: string, payload: AlertPushPayload): Promise<void> {
    try {
      const dogUsers = await getPrisma().dogUser.findMany({
        where: { dogId },
        include: { user: { select: { pushToken: true } } },
      });
      const tokens = dogUsers
        .map((du) => du.user.pushToken)
        .filter((t): t is string => !!t);

      if (tokens.length === 0) return;

      const response = await getMessaging().sendEachForMulticast({
        tokens,
        notification: { title: payload.title, body: payload.body },
        data: payload.data,
      });

      logger.info(
        { dogId, tokenCount: tokens.length, successCount: response.successCount },
        'Push notification sent',
      );
    } catch (err) {
      logger.warn({ dogId, err }, 'Push notification failed (non-fatal)');
    }
  },
};
