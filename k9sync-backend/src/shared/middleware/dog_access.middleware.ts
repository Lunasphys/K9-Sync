import { getPrisma } from '../../config/database.js';
import { ForbiddenError } from '../errors.js';

/**
 * Verifies [userId] has access to [dogId]: a DogUser row must exist and,
 * when it carries an expiresAt (dog-sitter grants are time-boxed; owner/
 * family are not), that date must not have passed.
 *
 * - requireOwner also gates owner-only actions (updateDog, pairCollar,
 *   invite, geofence...).
 * - excludeDogSitter also gates actions family can do but a dog_sitter
 *   can't — e.g. editing the vet record book: a sitter can read it
 *   (allergies, upcoming care) but shouldn't be the one maintaining it.
 *
 * Every dogId-scoped route must go through this — don't re-check
 * dogUser existence ad hoc, that's how the expiresAt check got missed
 * everywhere in the first place.
 */
export async function requireDogAccess(
  userId: string,
  dogId: string,
  opts: { requireOwner?: boolean; excludeDogSitter?: boolean } = {},
) {
  const access = await getPrisma().dogUser.findFirst({
    where: { userId, dogId },
  });

  if (!access) {
    throw new ForbiddenError('no access to this dog');
  }

  if (access.expiresAt && access.expiresAt < new Date()) {
    throw new ForbiddenError('access expired');
  }

  if (opts.requireOwner && access.role !== 'owner') {
    throw new ForbiddenError('owner only');
  }

  if (opts.excludeDogSitter && access.role === 'dog_sitter') {
    throw new ForbiddenError('dog sitters have read-only access to this resource');
  }

  return access;
}
