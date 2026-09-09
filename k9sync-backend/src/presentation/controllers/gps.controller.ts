import { FastifyRequest, FastifyReply } from 'fastify';
import { getPrisma } from '../../config/database.js';
import { logger } from '../../shared/logger.js';
import { requireDogAccess } from '../../shared/middleware/dog_access.middleware.js';

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

  // No collar paired yet means no history — a normal initial state for a
  // freshly-created dog, not a missing resource, so return an empty list.
  const collarId = await getCollarId(dogId);
  if (!collarId) return reply.send([]);

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
      trailId?: string;
    };
  }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  await requireDogAccess(req.userId, dogId);

  const collarId = await getCollarId(dogId);
  if (!collarId) return reply.status(404).send({ error: 'No collar paired' });

  const { locations, trailId } = req.body;
  if (!locations?.length) return reply.send({ synced: 0 });

  // trailId is optional and, when given, must belong to this dog's collar —
  // otherwise a client could link points onto another dog's trail.
  if (trailId) {
    const trail = await getPrisma().trail.findFirst({ where: { id: trailId, collarId } });
    if (!trail) return reply.status(404).send({ error: 'Trail not found' });
  }

  const result = await getPrisma().gpsLocation.createMany({
    data: locations.map((l) => ({
      collarId,
      latitude: l.latitude,
      longitude: l.longitude,
      accuracy: l.accuracy,
      recordedAt: new Date(l.recordedAt),
      syncedAt: new Date(),
      trailId,
    })),
    skipDuplicates: true,
  });

  logger.info({ dogId, synced: result.count }, 'GPS sync');
  return reply.send({ synced: result.count });
}
