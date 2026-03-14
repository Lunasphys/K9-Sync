import { FastifyInstance } from 'fastify';
import { jwtAuth } from '../../shared/middleware/jwt.middleware.js';
import { uploadDogPhoto } from '../controllers/upload.controller.js';

export async function uploadRoutes(app: FastifyInstance) {
  app.addHook('preHandler', jwtAuth);

  app.post('/upload/dog-photo', uploadDogPhoto);
}
