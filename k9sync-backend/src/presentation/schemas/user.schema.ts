import { z } from 'zod';

export const deleteAccountBodySchema = z.object({
  password: z.string().min(1),
});

export type DeleteAccountBody = z.infer<typeof deleteAccountBodySchema>;
