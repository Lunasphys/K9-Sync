import { FastifyInstance } from 'fastify';
import { UserController } from '../controllers/user.controller.js';
import { jwtAuth } from '../../shared/middleware/jwt.middleware.js';

// Routes aligned with Flutter api_constants: GET /v1/users/me
// All routes in this file require a valid JWT (jwtAuth preHandler).
export async function userRoutes(app: FastifyInstance) {
  const controller = new UserController();

  app.get('/me', { preHandler: jwtAuth, handler: controller.getMe });
}
