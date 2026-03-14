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

export async function getGpsLatest(
  req: FastifyRequest<{ Params: { dogId: string } }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  await requireDogAccess(req.userId, dogId);

  const collarId = await getCollarId(dogId);
  if (!collarId) return reply.status(404).send({ error: 'No collar paired' });

  const location = await getPrisma().gpsLocation.findFirst({
    where: { collarId },
    orderBy: { recordedAt: 'desc' },
  });

  if (!location) return reply.status(404).send({ error: 'No GPS data yet' });

  return reply.send({
    latitude: location.latitude,
    longitude: location.longitude,
    accuracy: location.accuracy,
    recordedAt: location.recordedAt,
  });
}

export async function getGpsHistory(
  req: FastifyRequest<{
    Params: { dogId: string };
    Querystring: { from?: string; to?: string; limit?: string };
  }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  const { from, to, limit } = req.query;
  await requireDogAccess(req.userId, dogId);

  const collarId = await getCollarId(dogId);
  if (!collarId) return reply.status(404).send({ error: 'No collar paired' });

  const locations = await getPrisma().gpsLocation.findMany({
    where: {
      collarId,
      ...(from || to
        ? {
            recordedAt: {
              ...(from ? { gte: new Date(from) } : {}),
              ...(to ? { lte: new Date(to) } : {}),
            },
          }
        : {}),
    },
    orderBy: { recordedAt: 'desc' },
    take: limit ? Math.min(parseInt(limit, 10), 1000) : 500,
  });

  return reply.send(locations);
}

export async function syncGps(
  req: FastifyRequest<{
    Params: { dogId: string };
    Body: {
      locations: Array<{
        latitude: number;
        longitude: number;
        accuracy?: number;
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

  const { locations } = req.body;
  if (!locations?.length) return reply.send({ synced: 0 });

  const result = await getPrisma().gpsLocation.createMany({
    data: locations.map((l) => ({
      collarId,
      latitude: l.latitude,
      longitude: l.longitude,
      accuracy: l.accuracy,
      recordedAt: new Date(l.recordedAt),
      syncedAt: new Date(),
    })),
    skipDuplicates: true,
  });

  logger.info({ dogId, synced: result.count }, 'GPS sync');
  return reply.send({ synced: result.count });
}
