import { FastifyRequest, FastifyReply } from 'fastify';
import { getPrisma } from '../../config/database.js';
import { logger } from '../../shared/logger.js';
import { requireDogAccess } from '../../shared/middleware/dog_access.middleware.js';
import { ValidationError } from '../../shared/errors.js';
import { createVetRecordBodySchema, updateVetRecordBodySchema } from '../schemas/vet_record.schema.js';

// ── POST /dogs/:dogId/vet-records ───────────────────────────────────────────

export async function createVetRecord(
  req: FastifyRequest<{ Params: { dogId: string }; Body: unknown }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  // Owner/family maintain the vet record book; a dog_sitter can read it
  // (allergies, upcoming care) but isn't the one keeping it up to date.
  await requireDogAccess(req.userId, dogId, { excludeDogSitter: true });

  const body = createVetRecordBodySchema.safeParse(req.body);
  if (!body.success) throw new ValidationError(body.error.flatten());
  const { title, date, done, notes } = body.data;

  const record = await getPrisma().vetRecord.create({
    data: {
      dogId,
      title,
      date: new Date(date),
      done: done ?? false,
      notes,
    },
  });

  logger.info({ dogId, vetRecordId: record.id }, 'Vet record created');
  return reply.status(201).send(record);
}

// ── GET /dogs/:dogId/vet-records ────────────────────────────────────────────

export async function getVetRecords(
  req: FastifyRequest<{ Params: { dogId: string } }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  await requireDogAccess(req.userId, dogId);

  const records = await getPrisma().vetRecord.findMany({
    where: { dogId },
    orderBy: { date: 'asc' },
  });

  return reply.send(records);
}

// ── PATCH /dogs/:dogId/vet-records/:recordId ────────────────────────────────

export async function updateVetRecord(
  req: FastifyRequest<{ Params: { dogId: string; recordId: string }; Body: unknown }>,
  reply: FastifyReply,
) {
  const { dogId, recordId } = req.params;
  await requireDogAccess(req.userId, dogId, { excludeDogSitter: true });

  const body = updateVetRecordBodySchema.safeParse(req.body);
  if (!body.success) throw new ValidationError(body.error.flatten());
  const { title, date, done, notes } = body.data;

  // Scoped to this dog, not just the id — a record belonging to another
  // dog must 404 here, not be editable through this endpoint.
  const existing = await getPrisma().vetRecord.findFirst({ where: { id: recordId, dogId } });
  if (!existing) return reply.status(404).send({ error: 'Vet record not found' });

  const record = await getPrisma().vetRecord.update({
    where: { id: recordId },
    data: {
      ...(title !== undefined && { title }),
      ...(date !== undefined && { date: new Date(date) }),
      ...(done !== undefined && { done }),
      ...(notes !== undefined && { notes }),
    },
  });

  logger.info({ dogId, vetRecordId: record.id }, 'Vet record updated');
  return reply.send(record);
}

// ── DELETE /dogs/:dogId/vet-records/:recordId ───────────────────────────────

export async function deleteVetRecord(
  req: FastifyRequest<{ Params: { dogId: string; recordId: string } }>,
  reply: FastifyReply,
) {
  const { dogId, recordId } = req.params;
  await requireDogAccess(req.userId, dogId, { excludeDogSitter: true });

  const existing = await getPrisma().vetRecord.findFirst({ where: { id: recordId, dogId } });
  if (!existing) return reply.status(404).send({ error: 'Vet record not found' });

  await getPrisma().vetRecord.delete({ where: { id: recordId } });

  logger.info({ dogId, vetRecordId: recordId }, 'Vet record deleted');
  return reply.status(204).send();
}
