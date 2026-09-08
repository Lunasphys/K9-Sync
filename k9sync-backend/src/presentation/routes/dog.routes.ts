import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { jwtAuth } from '../../shared/middleware/jwt.middleware.js';
import { getPrisma } from '../../config/database.js';
import {
  getDogs,
  createDog,
  getDog,
  updateDog,
  inviteToDog,
  listDogUsers,
  revokeDogUser,
  pairCollar,
} from '../controllers/dog.controller.js';
import { getHealthLatest, syncHealth } from '../controllers/health.controller.js';
import { upsertGeofence, deleteGeofence } from '../controllers/geofence.controller.js';
import { requireDogAccess } from '../../shared/middleware/dog_access.middleware.js';

export async function dogRoutes(app: FastifyInstance) {
  app.addHook('preHandler', jwtAuth);

  app.get('/dogs', getDogs);
  app.post('/dogs', createDog);
  app.get('/dogs/:dogId', getDog);
  app.patch('/dogs/:dogId', updateDog);

  // Partage multi-utilisateurs
  app.post('/dogs/:dogId/invite', inviteToDog);
  app.get('/dogs/:dogId/users', listDogUsers);
  app.delete('/dogs/:dogId/users/:userId', revokeDogUser);

  // Jumelage du collier
  app.post('/dogs/:dogId/collar/pair', pairCollar);

  // Geofencing — un seul cercle de zone par chien
  app.put('/dogs/:dogId/geofence', upsertGeofence);
  app.delete('/dogs/:dogId/geofence', deleteGeofence);

  app.get('/dogs/:dogId/health/latest', getHealthLatest);
  app.post('/dogs/:dogId/health/sync', syncHealth);

  // Alerts
  app.get<{
    Params: { dogId: string };
    Querystring: { unread?: string; limit?: string };
  }>('/dogs/:dogId/alerts', async (req, reply: FastifyReply) => {
    const { dogId } = req.params;
    await requireDogAccess(req.userId, dogId);
    const unreadOnly = req.query.unread === 'true';
    const limit = req.query.limit ? Math.min(parseInt(req.query.limit, 10), 100) : 50;
    const alerts = await getPrisma().alert.findMany({
      where: { dogId, ...(unreadOnly ? { read: false } : {}) },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
    return reply.send(alerts);
  });

  app.patch<{ Params: { dogId: string; alertId: string } }>(
    '/dogs/:dogId/alerts/:alertId/read',
    async (req, reply: FastifyReply) => {
      const { dogId, alertId } = req.params;
      await requireDogAccess(req.userId, dogId);
      const alert = await getPrisma().alert.findFirst({
        where: { id: alertId, dogId },
      });
      if (!alert) return reply.status(404).send({ error: 'Alert not found' });
      const updated = await getPrisma().alert.update({
        where: { id: alertId },
        data: { read: true },
      });
      return reply.send(updated);
    },
  );

  app.patch<{ Params: { dogId: string } }>(
    '/dogs/:dogId/alerts/read-all',
    async (req, reply: FastifyReply) => {
      const { dogId } = req.params;
      await requireDogAccess(req.userId, dogId);
      const result = await getPrisma().alert.updateMany({
        where: { dogId, read: false },
        data: { read: true },
      });
      return reply.send({ count: result.count });
    },
  );
}

