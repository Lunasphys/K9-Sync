import { FastifyRequest, FastifyReply } from 'fastify';
import { getPrisma } from '../../config/database.js';
import { logger } from '../../shared/logger.js';
import { requireDogAccess } from '../../shared/middleware/dog_access.middleware.js';

async function getCollarId(dogId: string): Promise<string | null> {
  const collar = await getPrisma().collar.findFirst({ where: { dogId } });
  return collar?.id ?? null;
}

export async function createTrail(
  req: FastifyRequest<{
    Params: { dogId: string };
    Body: {
      startedAt: string;
      endedAt: string;
      distanceM: number;
      durationS: number;
      pointsCount: number;
    };
  }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  await requireDogAccess(req.userId, dogId);

  const collarId = await getCollarId(dogId);
  if (!collarId) return reply.status(404).send({ error: 'No collar paired' });

  const { startedAt, endedAt, distanceM, durationS, pointsCount } = req.body;

  const trail = await getPrisma().trail.create({
    data: {
      collarId,
      startedAt: new Date(startedAt),
      endedAt: new Date(endedAt),
      distanceM,
      durationS,
      pointsCount,
    },
  });

  logger.info({ dogId, trailId: trail.id }, 'Trail created');
  return reply.status(201).send(trail);
}

export async function getTrails(
  req: FastifyRequest<{ Params: { dogId: string } }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  await requireDogAccess(req.userId, dogId);

  // A dog with no collar paired yet simply has no trails — that's a normal
  // initial state, not a missing/forbidden resource, so this stays a 200
  // with an empty list rather than a 404.
  const collarId = await getCollarId(dogId);
  if (!collarId) return reply.send([]);

  const trails = await getPrisma().trail.findMany({
    where: { collarId },
    orderBy: { startedAt: 'desc' },
  });

  return reply.send(trails);
}

export async function getTrailById(
  req: FastifyRequest<{ Params: { dogId: string; trailId: string } }>,
  reply: FastifyReply,
) {
  const { dogId, trailId } = req.params;
  await requireDogAccess(req.userId, dogId);

  const collarId = await getCollarId(dogId);
  if (!collarId) return reply.status(404).send({ error: 'No collar paired' });

  // Scoped to this dog's collar, not just the id — a trail belonging to
  // another dog must 404 here, not leak its points.
  const trail = await getPrisma().trail.findFirst({
    where: { id: trailId, collarId },
  });
  if (!trail) return reply.status(404).send({ error: 'Trail not found' });

  const points = await getPrisma().gpsLocation.findMany({
    where: { trailId: trail.id },
    orderBy: { recordedAt: 'asc' },
  });

  return reply.send({ ...trail, points });
}
