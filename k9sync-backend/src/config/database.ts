import { PrismaClient } from '@prisma/client';

let prismaInstance: PrismaClient | null = null;

export function initPrisma(datasourceUrl: string): PrismaClient {
  prismaInstance = new PrismaClient({
    datasourceUrl,
    log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
  });
  return prismaInstance;
}

export function getPrisma(): PrismaClient {
  if (!prismaInstance) throw new Error('initPrisma() must be called before getPrisma()');
  return prismaInstance;
}
