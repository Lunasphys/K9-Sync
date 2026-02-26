import { FastifyInstance } from 'fastify';
import { AuthController } from '../controllers/auth.controller.js';

/**
 * Auth routes — aligned with Flutter api_constants:
 * /auth/register, /auth/login, /auth/refresh, /auth/logout, /auth/forgot-password
 * Response: { user, accessToken, refreshToken } for login/register/refresh.
 * Validation body faite dans le controller avec Zod.
 */
export async function authRoutes(app: FastifyInstance) {
  const controller = new AuthController();

  app.post<{ Body: unknown }>('/register', { handler: controller.register });
  app.post<{ Body: unknown }>('/login', { handler: controller.login });
  app.post<{ Body: unknown }>('/refresh', { handler: controller.refresh });
  app.post('/logout', { handler: controller.logout });
  app.post<{ Body: unknown }>('/forgot-password', { handler: controller.forgotPassword });
}
