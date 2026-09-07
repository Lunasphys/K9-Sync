import { z } from 'zod';

// Duplicated from AppConstants.geofenceRadiusMinM on the Flutter side — no
// shared source between the two codebases (same pattern as JWT expiry,
// heart-rate/temperature thresholds, etc., each independently defined).
export const GEOFENCE_RADIUS_MIN_M = 10;

// Shape/type validation only — the minimum-radius business rule is checked
// in the controller so it can throw the dedicated GeofenceRadiusTooSmallError
// instead of a generic ValidationError.
export const upsertGeofenceBodySchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  radiusM: z.number().int().positive(),
});

export type UpsertGeofenceBody = z.infer<typeof upsertGeofenceBodySchema>;
