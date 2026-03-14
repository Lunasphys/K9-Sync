/**
 * Doit être importé en premier dans server.ts.
 * Charge .env depuis la racine du backend ou depuis process.cwd().
 */
import path from 'node:path';
import { config } from 'dotenv';
import { existsSync } from 'node:fs';

const envPath = path.resolve(__dirname, '..', '.env');
const cwdPath = path.resolve(process.cwd(), '.env');
// Charger depuis cwd (quand on lance "npm run dev" depuis k9sync-backend) ou depuis le dossier du backend
if (existsSync(cwdPath)) config({ path: cwdPath });
else if (existsSync(envPath)) config({ path: envPath });
else config(); // dotenv cherche .env dans cwd
