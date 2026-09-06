import { z } from 'zod';

// Rôles distribuables par invitation. `owner` est assigné automatiquement à
// la création du chien (POST /dogs) et n'est jamais accordé via /invite.
export const inviteRoleSchema = z.enum(['family', 'dog_sitter']);

export const inviteBodySchema = z
  .object({
    email: z.string().email(),
    role: inviteRoleSchema,
    expiresAt: z.string().datetime().optional(),
  })
  .refine((data) => data.role !== 'dog_sitter' || data.expiresAt !== undefined, {
    message: 'expiresAt is required when role is dog_sitter',
    path: ['expiresAt'],
  });

export type InviteBody = z.infer<typeof inviteBodySchema>;
