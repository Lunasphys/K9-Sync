import { FastifyRequest, FastifyReply } from 'fastify';
import { getPrisma } from '../../config/database.js';
import { logger } from '../../shared/logger.js';
import { ValidationError, GeofenceRadiusTooSmallError } from '../../shared/errors.js';
import { requireDogAccess } from '../../shared/middleware/dog_access.middleware.js';
import { upsertGeofenceBodySchema, GEOFENCE_RADIUS_MIN_M } from '../schemas/geofence.schema.js';

// ── PUT /dogs/:dogId/geofence ───────────────────────────────────────────────

/**
 * Un seul cercle de zone par chien (scope réduit — pas de zones multiples,
 * pas d'horaires) : upsert sur la contrainte unique dogId plutôt qu'une
 * création distincte, pour que "modifier la zone" et "créer la zone" soient
 * la même opération côté client.
 *
 * isInside repart toujours à true : (re)définir la zone donne une base
 * "présumé dedans" fraîche, et c'est le prochain point GPS reçu qui
 * détermine l'état réel — déclenchant une alerte de sortie immédiatement
 * si le chien n'est en fait pas dans la zone qui vient d'être dessinée.
 */
export async function upsertGeofence(
  req: FastifyRequest<{ Params: { dogId: string }; Body: unknown }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  await requireDogAccess(req.userId, dogId, { requireOwner: true });

  const body = upsertGeofenceBodySchema.safeParse(req.body);
  if (!body.success) throw new ValidationError(body.error.flatten());
  const { latitude, longitude, radiusM } = body.data;

  if (radiusM < GEOFENCE_RADIUS_MIN_M) {
    throw new GeofenceRadiusTooSmallError(radiusM, GEOFENCE_RADIUS_MIN_M);
  }

  const zone = await getPrisma().geofenceZone.upsert({
    where: { dogId },
    create: { dogId, latitude, longitude, radiusM, isInside: true },
    update: { latitude, longitude, radiusM, isInside: true },
  });

  logger.info({ dogId, radiusM }, 'Geofence zone upserted');
  return reply.status(200).send(zone);
}

// ── DELETE /dogs/:dogId/geofence ────────────────────────────────────────────

export async function deleteGeofence(
  req: FastifyRequest<{ Params: { dogId: string } }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  await requireDogAccess(req.userId, dogId, { requireOwner: true });

  // deleteMany, not delete: idempotent, no error if there was no zone yet.
  await getPrisma().geofenceZone.deleteMany({ where: { dogId } });

  logger.info({ dogId }, 'Geofence zone deleted');
  return reply.status(204).send();
}
