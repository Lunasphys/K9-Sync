import { FastifyRequest, FastifyReply } from 'fastify';
import { getPrisma } from '../../config/database.js';
import { logger } from '../../shared/logger.js';

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Resolve collarId from dogId. Returns null if no collar paired. */
async function getCollarId(dogId: string): Promise<string | null> {
  const collar = await getPrisma().collar.findFirst({ where: { dogId } });
  return collar?.id ?? null;
}

async function requireDogAccess(userId: string, dogId: string) {
  const access = await getPrisma().dogUser.findFirst({
    where: {
      userId,
      dogId,
    },
  });
  if (!access) {
    const err: any = new Error('Forbidden');
    err.statusCode = 403;
    throw err;
  }
}

// ── GET /dogs/:dogId/health/latest ────────────────────────────────────────────

export async function getHealthLatest(
  req: FastifyRequest<{ Params: { dogId: string } }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  await requireDogAccess(req.userId, dogId);

  const collarId = await getCollarId(dogId);
  if (!collarId) return reply.status(404).send({ error: 'No collar paired' });

  const record = await getPrisma().healthRecord.findFirst({
    where: { collarId },
    orderBy: { recordedAt: 'desc' },
  });

  if (!record) return reply.status(404).send({ error: 'No health data yet' });

  return reply.send({
    heartRate: record.heartRate,
    temperature: record.temperature,
    recordedAt: record.recordedAt,
  });
}

// ── POST /dogs/:dogId/health/sync ─────────────────────────────────────────────

export async function syncHealth(
  req: FastifyRequest<{
    Params: { dogId: string };
    Body: {
      records: Array<{
        heartRate?: number;
        temperature?: number;
        steps?: number;
        activeMinutes?: number;
        anomalyDetected?: boolean;
        anomalyType?: string;
        recordedAt: string;
      }>;
    };
  }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  await requireDogAccess(req.userId, dogId);

  const collarId = await getCollarId(dogId);
  if (!collarId) return reply.status(404).send({ error: 'No collar paired' });

  const { records } = req.body;
  if (!records?.length) return reply.send({ synced: 0 });

  // Insert with skipDuplicates — unique constraint on (collarId, recordedAt)
  const result = await getPrisma().healthRecord.createMany({
    data: records.map((r) => ({
      collarId,
      heartRate: r.heartRate,
      temperature: r.temperature,
      recordedAt: new Date(r.recordedAt),
      syncedAt: new Date(),
    })),
    skipDuplicates: true,
  });

  // Anomaly detection on each inserted record
  for (const r of records) {
    const hr = r.heartRate;
    const temp = r.temperature;
    const isHrAnomaly = hr !== undefined && (hr > 180 || hr < 50);
    const isTempAnomaly = temp !== undefined && (temp > 39.5 || temp < 36.0);

    if (isHrAnomaly || isTempAnomaly) {
      const type = isHrAnomaly ? 'heart_rate' : 'temperature';
      const value = isHrAnomaly ? hr : temp;
      const label = isHrAnomaly
        ? `Fréquence cardiaque anormale — ${value} bpm (seuil : 50–180 bpm)`
        : `Température anormale — ${value}°C (seuil : 36–39.5°C)`;

      await getPrisma().alert.create({
        data: {
          dogId,
          type,
          title: label,
        },
      });

      logger.warn({ dogId, type, value }, 'Anomaly alert created');
    }
  }

  logger.info({ dogId, synced: result.count }, 'Health sync');
  return reply.send({ synced: result.count });
}

