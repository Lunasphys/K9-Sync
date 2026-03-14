import { getPrisma } from '../config/database.js';
import { logger } from '../shared/logger.js';

/**
 * Call from your MQTT broker subscription handler (e.g. server.ts or mqtt.service.ts)
 * when a message arrives from a collar topic.
 * Topic pattern: k9sync/collar/{serial}/+
 * Usage: await handleCollarMessage(serial, topic, payload)
 */
export async function handleCollarMessage(
  serial: string,
  topic: string,
  _payload: Record<string, unknown>,
): Promise<void> {
  const updated = await getPrisma().collar.updateMany({
    where: { serialNumber: serial },
    data: {
      isOnline: true,
      lastSeenAt: new Date(),
    },
  });

  if (updated.count === 0) {
    logger.warn({ serial }, 'MQTT message from unknown collar');
    return;
  }

  logger.debug({ serial, topic }, 'Collar heartbeat updated');
}

/**
 * Run via cron every 5 minutes (e.g. in server.ts or jobs/cron.ts).
 * Collars with no message in the last 10 minutes are marked offline.
 */
export async function markStaleCollarsOffline(): Promise<void> {
  const threshold = new Date(Date.now() - 10 * 60 * 1000);

  const result = await getPrisma().collar.updateMany({
    where: {
      isOnline: true,
      lastSeenAt: { lt: threshold },
    },
    data: { isOnline: false },
  });

  if (result.count > 0) {
    logger.info({ count: result.count }, 'Collars marked offline (stale)');
  }
}
