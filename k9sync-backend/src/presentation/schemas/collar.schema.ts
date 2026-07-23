import { z } from 'zod';

// Payloads published by the collar (or collar_simulator.py) on
// k9sync/collar/{serial}/gps and k9sync/collar/{serial}/health.
// `dogId` is informational only — the authoritative collar → dog pairing
// is looked up server-side from `collarSerial`, never trusted from the payload.

export const gpsMessageSchema = z.object({
  collarSerial: z.string().min(1),
  dogId: z.string().optional(),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  accuracy: z.number().nonnegative().optional(),
  recordedAt: z.string().min(1),
});

export type GpsMessage = z.infer<typeof gpsMessageSchema>;

export const healthMessageSchema = z.object({
  collarSerial: z.string().min(1),
  dogId: z.string().optional(),
  heartRate: z.number().int().nonnegative().optional(),
  temperature: z.number().optional(),
  steps: z.number().int().nonnegative().optional(),
  activeMinutes: z.number().int().nonnegative().optional(),
  anomalyDetected: z.boolean().optional(),
  anomalyType: z.string().optional(),
  recordedAt: z.string().min(1),
});

export type HealthMessage = z.infer<typeof healthMessageSchema>;
