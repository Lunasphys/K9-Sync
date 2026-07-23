import { FastifyInstance } from 'fastify';
import { jwtAuth } from '../../shared/middleware/jwt.middleware.js';
import { getGpsLatest, getGpsHistory, syncGps } from '../controllers/gps.controller.js';
import { syncActivity, getActivitySummary } from '../controllers/activity.controller.js';

export async function gpsActivityRoutes(app: FastifyInstance) {
  app.addHook('preHandler', jwtAuth);

  app.get('/dogs/:dogId/gps/latest', getGpsLatest);
  app.get('/dogs/:dogId/gps/history', getGpsHistory);
  app.post('/dogs/:dogId/gps/sync', syncGps);

  app.get('/dogs/:dogId/activity', getActivitySummary);
  app.post('/dogs/:dogId/activity/sync', syncActivity);
}
