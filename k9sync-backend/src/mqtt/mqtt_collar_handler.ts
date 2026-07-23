import { getPrisma } from '../config/database.js';
import { logger } from '../shared/logger.js';
import { gpsMessageSchema, healthMessageSchema } from '../presentation/schemas/collar.schema.js';

const HR_MIN = 50;
const HR_MAX = 180;
const TEMP_MIN = 36.0;
const TEMP_MAX = 39.5;

/**
 * Resolve a collar's DB id from its serial number and mark it online.
 * Returns null if no collar with this serial is paired yet.
 */
async function resolveCollarId(serial: string): Promise<string | null> {
  const collar = await getPrisma().collar.findUnique({
    where: { serialNumber: serial },
  });
  if (!collar) return null;

  await getPrisma().collar.update({
    where: { id: collar.id },
    data: { isOnline: true, lastSeenAt: new Date() },
  });

  return collar.id;
}

export async function handleGpsMessage(serial: string, raw: unknown): Promise<void> {
  const parsed = gpsMessageSchema.safeParse(raw);
  if (!parsed.success) {
    logger.warn({ serial, issues: parsed.error.flatten() }, 'Malformed GPS MQTT payload — dropped');
    return;
  }

  const collarId = await resolveCollarId(serial);
  if (!collarId) {
    logger.warn({ serial }, 'GPS message from unknown/unpaired collar serial — dropped');
    return;
  }

  const { latitude, longitude, accuracy, recordedAt } = parsed.data;
  await getPrisma().gpsLocation.create({
    data: {
      collarId,
      latitude,
      longitude,
      accuracy,
      recordedAt: new Date(recordedAt),
    },
  });

  logger.debug({ serial, collarId }, 'GPS location stored via MQTT');
}

export async function handleHealthMessage(serial: string, raw: unknown): Promise<void> {
  const parsed = healthMessageSchema.safeParse(raw);
  if (!parsed.success) {
    logger.warn({ serial, issues: parsed.error.flatten() }, 'Malformed health MQTT payload — dropped');
    return;
  }

  const collarId = await resolveCollarId(serial);
  if (!collarId) {
    logger.warn({ serial }, 'Health message from unknown/unpaired collar serial — dropped');
    return;
  }

  const { heartRate, temperature, recordedAt } = parsed.data;
  const isHrAnomaly = heartRate !== undefined && (heartRate > HR_MAX || heartRate < HR_MIN);
  const isTempAnomaly = temperature !== undefined && (temperature > TEMP_MAX || temperature < TEMP_MIN);

  const record = await getPrisma().healthRecord.create({
    data: {
      collarId,
      heartRate,
      temperature,
      anomalyDetected: isHrAnomaly || isTempAnomaly,
      anomalyType: isHrAnomaly ? 'heart_rate' : isTempAnomaly ? 'temperature' : undefined,
      recordedAt: new Date(recordedAt),
    },
  });

  logger.debug({ serial, collarId, recordId: record.id }, 'Health record stored via MQTT');

  if (isHrAnomaly || isTempAnomaly) {
    const collar = await getPrisma().collar.findUnique({ where: { id: collarId } });
    if (collar) {
      const type = isHrAnomaly ? 'heart_rate' : 'temperature';
      const value = isHrAnomaly ? heartRate : temperature;
      const title = isHrAnomaly
        ? `Fréquence cardiaque anormale — ${value} bpm (seuil : ${HR_MIN}–${HR_MAX} bpm)`
        : `Température anormale — ${value}°C (seuil : ${TEMP_MIN}–${TEMP_MAX}°C)`;

      await getPrisma().alert.create({
        data: { dogId: collar.dogId, type, title },
      });

      logger.warn({ serial, collarId, type, value }, 'Anomaly alert created from MQTT');
    }
  }
}

/**
 * Run periodically (e.g. via cron every 5 minutes). Collars with no
 * message in the last 10 minutes are marked offline.
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
