import path from 'path';
import fs from 'fs';
import { FastifyRequest, FastifyReply } from 'fastify';
import { logger } from '../../shared/logger.js';

const UPLOAD_DIR = path.join(process.cwd(), 'uploads');

if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

const ALLOWED_MIME = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB

export async function uploadDogPhoto(
  req: FastifyRequest,
  reply: FastifyReply,
) {
  const data = await req.file();

  if (!data) {
    return reply.status(400).send({ error: 'No file provided' });
  }

  if (!ALLOWED_MIME.includes(data.mimetype)) {
    return reply
      .status(400)
      .send({ error: 'Only JPEG, PNG and WebP are allowed' });
  }

  const chunks: Buffer[] = [];
  let totalSize = 0;

  for await (const chunk of data.file) {
    totalSize += chunk.length;
    if (totalSize > MAX_SIZE_BYTES) {
      return reply.status(413).send({ error: 'File too large (max 5 MB)' });
    }
    chunks.push(chunk);
  }

  const ext = data.mimetype === 'image/png' ? 'png'
    : data.mimetype === 'image/webp' ? 'webp'
    : 'jpg';

  const filename = `dog_${req.userId}_${Date.now()}.${ext}`;
  const filePath = path.join(UPLOAD_DIR, filename);

  fs.writeFileSync(filePath, Buffer.concat(chunks));

  const url = `/uploads/${filename}`;

  logger.info({ userId: req.userId, filename, size: totalSize }, 'Dog photo uploaded');

  return reply.send({ url });
}
