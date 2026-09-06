import { z } from 'zod';

export const deleteAccountBodySchema = z.object({
  password: z.string().min(1),
});

export type DeleteAccountBody = z.infer<typeof deleteAccountBodySchema>;

// RGPD — les seuls types de consentement gérés ce soir. Étendre cette liste
// au besoin (ex. "community_features") suffit à couvrir un nouveau type.
export const consentTypeSchema = z.enum([
  'terms_of_service',
  'gps_data_collection',
  'health_data_collection',
]);

export const consentEntrySchema = z.object({
  type: consentTypeSchema,
  accepted: z.boolean(),
  version: z.string().min(1),
});

export const postConsentsBodySchema = z.object({
  consents: z.array(consentEntrySchema).min(1),
});

export type ConsentType = z.infer<typeof consentTypeSchema>;
export type PostConsentsBody = z.infer<typeof postConsentsBodySchema>;

export const pushTokenBodySchema = z.object({
  token: z.string().min(1),
});

export type PushTokenBody = z.infer<typeof pushTokenBodySchema>;
