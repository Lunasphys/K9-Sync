import { z } from 'zod';

// Simplified vet record — free-text title, no vaccine/antiparasitic/etc.
// type distinction and no automatic recurrence (see VetRecord in schema.prisma).
export const createVetRecordBodySchema = z.object({
  title: z.string().trim().min(1),
  date: z.string().datetime(),
  done: z.boolean().optional(),
  notes: z.string().trim().min(1).optional(),
});

export type CreateVetRecordBody = z.infer<typeof createVetRecordBodySchema>;

export const updateVetRecordBodySchema = z
  .object({
    title: z.string().trim().min(1).optional(),
    date: z.string().datetime().optional(),
    done: z.boolean().optional(),
    notes: z.string().trim().min(1).nullable().optional(),
  })
  .refine((data) => Object.keys(data).length > 0, {
    message: 'at least one field must be provided',
  });

export type UpdateVetRecordBody = z.infer<typeof updateVetRecordBodySchema>;
