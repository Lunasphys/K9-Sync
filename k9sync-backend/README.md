# K9 Sync — Backend API

API Node.js / Fastify pour K9 Sync : auth, chiens, colliers, GPS, santé, alertes. Alignée avec le frontend Flutter (voir `FRONTEND_ALIGNMENT.md`).

## Prérequis

- Node 20+
- PostgreSQL 15+
- (optionnel) Redis, Mosquitto MQTT

## Installation

```bash
npm install
cp .env.example .env
# Éditer .env (DATABASE_URL, JWT_ACCESS_SECRET, etc.)
npx prisma migrate dev
npm run dev
```

L’API écoute sur `http://localhost:3000`. Préfixe des routes : `/v1` (ex. `POST /v1/auth/login`).

## Scripts

- `npm run dev` — démarrage en watch (tsx)
- `npm run build` — compilation TypeScript
- `npm run start` — production (node dist/server.js)
- `npm run db:migrate` — migrations Prisma
- `npm run db:studio` — Prisma Studio

## Docker (dev local)

```bash
docker compose up -d
# API sur :3000, Postgres :5432, Redis :6379, Mosquitto :1883, Adminer :8080
```

## Firebase Admin SDK (FCM)

Pour les push notifications : placer le fichier de clé de compte de service (JSON) dans un dossier non versionné (ex. `config/`) et définir `GOOGLE_APPLICATION_CREDENTIALS` dans `.env`. Ne jamais committer ce fichier.

## Alignement frontend

Voir **FRONTEND_ALIGNMENT.md** pour la correspondance avec `lib/core/constants/api_constants.dart` et les points d’attention par rapport au document « K9 Sync Complement Backend ».
