import { getPrisma } from '../config/database.js';
import { logger } from '../shared/logger.js';
import { gpsMessageSchema, healthMessageSchema } from '../presentation/schemas/collar.schema.js';
import { pushNotifications } from '../shared/push_notifications.js';
import { distanceMeters } from '../shared/geo.js';

const HR_MIN = 50;
const HR_MAX = 180;
const TEMP_MIN = 36.0;
const TEMP_MAX = 39.5;

/**
 * Compares the collar's latest position to the dog's geofence zone (if any)
 * and reacts only on the dedans->dehors transition — an alert fires once per
 * exit, not on every GPS message received while the dog stays outside.
 * Re-entering the zone silently resets the state (no "welcome back" alert)
 * so the next exit fires again.
 */
async function checkGeofence(dogId: string, latitude: number, longitude: number): Promise<void> {
  const zone = await getPrisma().geofenceZone.findUnique({ where: { dogId } });
  if (!zone) return;

  const distance = distanceMeters(latitude, longitude, zone.latitude, zone.longitude);
  const isInside = distance <= zone.radiusM;
  if (isInside === zone.isInside) return;

  await getPrisma().geofenceZone.update({ where: { dogId }, data: { isInside } });

  if (isInside) {
    logger.info({ dogId }, 'Geofence re-entry detected');
    return;
  }

  const title = `Sortie de la zone définie (rayon ${zone.radiusM}m)`;
  await getPrisma().alert.create({ data: { dogId, type: 'geofence', title } });
  await pushNotifications.notifyDogAccessHolders(dogId, {
    title: 'Sortie de zone',
    body: title,
    data: { type: 'geofence', dogId, severity: 'high' },
  });
  logger.warn({ dogId, distance, radiusM: zone.radiusM }, 'Geofence exit detected');
}

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

  const collar = await getPrisma().collar.findUnique({ where: { id: collarId } });
  if (collar?.dogId) {
    await checkGeofence(collar.dogId, latitude, longitude);
  }
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

  const { heartRate, temperature, steps, activeMinutes, sleepPhase, recordedAt } = parsed.data;
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

  // Same message also carries activity/sleep telemetry (steps, activeMinutes,
  // sleepPhase) — previously accepted by the schema but silently dropped here.
  if (steps !== undefined || activeMinutes !== undefined || sleepPhase !== undefined) {
    await getPrisma().activityRecord.create({
      data: {
        collarId,
        steps: steps ?? 0,
        activeMinutes: activeMinutes ?? 0,
        sleepPhase: sleepPhase ?? 'awake',
        recordedAt: new Date(recordedAt),
      },
    });
    logger.debug({ serial, collarId, sleepPhase }, 'Activity record stored via MQTT');
  }

  if (isHrAnomaly || isTempAnomaly) {
    const collar = await getPrisma().collar.findUnique({ where: { id: collarId } });
    // A collar not yet paired to a dog (dogId null) can still broadcast — there's
    // just no dog to attach the alert to yet, so skip it until it's paired.
    if (collar?.dogId) {
      const type = isHrAnomaly ? 'heart_rate' : 'temperature';
      const value = isHrAnomaly ? heartRate : temperature;
      const title = isHrAnomaly
        ? `Fréquence cardiaque anormale — ${value} bpm (seuil : ${HR_MIN}–${HR_MAX} bpm)`
        : `Température anormale — ${value}°C (seuil : ${TEMP_MIN}–${TEMP_MAX}°C)`;

      await getPrisma().alert.create({
        data: { dogId: collar.dogId, type, title },
      });
      await pushNotifications.notifyDogAccessHolders(collar.dogId, {
        title: 'Alerte santé',
        body: title,
        data: { type, dogId: collar.dogId, severity: 'critical' },
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
