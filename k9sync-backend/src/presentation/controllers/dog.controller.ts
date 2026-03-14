import { FastifyRequest, FastifyReply } from 'fastify';
import { getPrisma } from '../../config/database.js';
import { logger } from '../../shared/logger.js';

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Verify req.userId has access to dogId. Returns the dogUser row or throws. */
async function requireDogAccess(
  userId: string,
  dogId: string,
  requireOwner = false,
) {
  const access = await getPrisma().dogUser.findFirst({
    where: {
      userId,
      dogId,
    },
  });

  if (!access) {
    const err: any = new Error('Forbidden');
    err.statusCode = 403;
    throw err;
  }

  if (requireOwner && access.role !== 'owner') {
    const err: any = new Error('Owner only');
    err.statusCode = 403;
    throw err;
  }

  return access;
}

// ── GET /dogs ─────────────────────────────────────────────────────────────────

export async function getDogs(req: FastifyRequest, reply: FastifyReply) {
  const userDogs = await getPrisma().dogUser.findMany({
    where: {
      userId: req.userId,
    },
    include: { dog: true },
  });

  const dogs = userDogs.map((ud) => ud.dog);
  logger.info({ userId: req.userId, count: dogs.length }, 'GET /dogs');
  return reply.send(dogs);
}

// ── POST /dogs ────────────────────────────────────────────────────────────────

export async function createDog(
  req: FastifyRequest<{
    Body: {
      name: string;
      breed?: string;
      birthDate?: string;
      weight?: number;
      sex?: string;
      allergies?: string[];
      photoUrl?: string;
    };
  }>,
  reply: FastifyReply,
) {
  const { name, breed, birthDate, weight, sex, allergies, photoUrl } = req.body;

  const dog = await getPrisma().dog.create({
    data: {
      name,
      breed,
      birthDate: birthDate ? new Date(birthDate) : undefined,
      weight,
      sex,
      allergies: allergies ?? [],
      photoUrl,
    },
  });

  // Automatically make the creator the owner
  await getPrisma().dogUser.create({
    data: {
      userId: req.userId,
      dogId: dog.id,
      role: 'owner',
    },
  });

  logger.info({ userId: req.userId, dogId: dog.id }, 'Dog created');
  return reply.status(201).send(dog);
}

// ── GET /dogs/:dogId ──────────────────────────────────────────────────────────

export async function getDog(
  req: FastifyRequest<{ Params: { dogId: string } }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  await requireDogAccess(req.userId, dogId);

  const dog = await getPrisma().dog.findUnique({ where: { id: dogId } });
  if (!dog) return reply.status(404).send({ error: 'Dog not found' });

  return reply.send(dog);
}

// ── PATCH /dogs/:dogId ────────────────────────────────────────────────────────

export async function updateDog(
  req: FastifyRequest<{
    Params: { dogId: string };
    Body: {
      name?: string;
      breed?: string;
      birthDate?: string;
      weight?: number;
      sex?: string;
      allergies?: string[];
      photoUrl?: string;
    };
  }>,
  reply: FastifyReply,
) {
  const { dogId } = req.params;
  await requireDogAccess(req.userId, dogId, true); // owner only

  const { birthDate, name, breed, weight, sex, allergies, photoUrl } = req.body;
  const data: Record<string, unknown> = {};
  if (name !== undefined) data.name = name;
  if (breed !== undefined) data.breed = breed;
  if (birthDate) data.birthDate = new Date(birthDate);
  if (weight !== undefined) data.weight = weight;
  if (sex !== undefined) data.sex = sex;
  if (allergies !== undefined) data.allergies = allergies;
  if (photoUrl !== undefined) data.photoUrl = photoUrl;

  const dog = await getPrisma().dog.update({
    where: { id: dogId },
    data,
  });

  logger.info({ userId: req.userId, dogId }, 'Dog updated');
  return reply.send(dog);
}

