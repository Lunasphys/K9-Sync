import { FastifyRequest, FastifyReply } from 'fastify';
import { getPrisma } from '../../config/database.js';
import { logger } from '../../shared/logger.js';

async function requireDogAccess(userId: string, dogId: string) {
  const access = await getPrisma().dogUser.findFirst({
    where: { userId, dogId },
  });
  if (!access) {
    const err: any = new Error('Forbidden');
    err.statusCode = 403;
    throw err;
  }
}

async function getCollarId(dogId: string): Promise<string | null> {
  const collar = await getPrisma().collar.findFirst({ where: { dogId } });
  return collar?.id ?? null;
}

export async function syncActivity(
  req: FastifyRequest<{
    Params: { dogId: string };
    Body: {
      records: Array<{
        steps?: number;
        activeMinutes?: number;
        restMinutes?: number;
        sleepPhase?: string;
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

  const result = await getPrisma().activityRecord.createMany({
    data: records.map((r) => ({
      collarId,
      steps: r.steps ?? 0,
      activeMinutes: r.activeMinutes ?? 0,
      restMinutes: r.restMinutes ?? 0,
      sleepPhase: (r.sleepPhase ?? 'awake') as string,
      anomalyDetected: r.anomalyDetected ?? false,
      anomalyType: (r.anomalyType ?? null) as string | null,
      recordedAt: new Date(r.recordedAt),
      syncedAt: new Date(),
    })),
    skipDuplicates: true,
  });

  const label: Record<string, string> = {
    fall: 'Chute détectée',
    trembling: 'Tremblements détectés',
    limping: 'Boiterie détectée',
    scratching: 'Grattage excessif détecté',
    inactivity: 'Inactivité prolongée détectée',
  };

  for (const r of records) {
    if (!r.anomalyDetected || !r.anomalyType || r.anomalyType === 'none') continue;
    const title = label[r.anomalyType] ?? `Anomalie : ${r.anomalyType}`;
    await getPrisma().alert.create({
      data: {
        dogId,
        type: r.anomalyType,
        title,
      },
    });
    logger.warn({ dogId, anomalyType: r.anomalyType }, 'Activity anomaly alert created');
  }

  logger.info({ dogId, synced: result.count }, 'Activity sync');
  return reply.send({ synced: result.count });
}

export async function getActivitySummary(
  req: FastifyRequest<{
    Params: { dogId: string };
    Querystring: { date?: string };
  }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  const { date } = req.query;
  await requireDogAccess(req.userId, dogId);

  const collarId = await getCollarId(dogId);
  if (!collarId) return reply.status(404).send({ error: 'No collar paired' });

  const day = date ? new Date(date) : new Date();
  const startOfDay = new Date(day);
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date(day);
  endOfDay.setHours(23, 59, 59, 999);

  const result = await getPrisma().activityRecord.aggregate({
    where: {
      collarId,
      recordedAt: { gte: startOfDay, lte: endOfDay },
    },
    _sum: {
      steps: true,
      activeMinutes: true,
      restMinutes: true,
    },
    _count: { id: true },
  });

  const anomalyCount = await getPrisma().activityRecord.count({
    where: {
      collarId,
      recordedAt: { gte: startOfDay, lte: endOfDay },
      anomalyDetected: true,
    },
  });

  return reply.send({
    date: day.toISOString().split('T')[0],
    totalSteps: result._sum.steps ?? 0,
    activeMinutes: result._sum.activeMinutes ?? 0,
    restMinutes: result._sum.restMinutes ?? 0,
    anomalyCount,
    recordCount: result._count.id,
  });
}
