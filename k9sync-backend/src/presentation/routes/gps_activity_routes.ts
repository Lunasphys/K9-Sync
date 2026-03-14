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

// ── app.ts patch ──────────────────────────────────────────────────────────────
// Add to src/app.ts (after other route registrations, same prefix as dogRoutes):
//
// import { gpsActivityRoutes } from './presentation/routes/gps_activity_routes.js';
//
// await app.register(gpsActivityRoutes, { prefix });
//
// Optional — MQTT + cron (e.g. in server.ts or where MQTT client lives):
// import { handleCollarMessage, markStaleCollarsOffline } from './mqtt/mqtt_collar_handler.js';
// import cron from 'node-cron';
//
// In MQTT message callback:
//   const parts = topic.split('/'); // k9sync/collar/{serial}/gps
//   if (parts[0] === 'k9sync' && parts[1] === 'collar') {
//     const serial = parts[2];
//     await handleCollarMessage(serial, topic, JSON.parse(message.toString()));
//   }
//
// Cron — mark stale collars offline every 5 minutes:
//   cron.schedule('*/5 * * * *', markStaleCollarsOffline);
