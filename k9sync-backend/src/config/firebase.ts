import { initializeApp, applicationDefault, type App } from 'firebase-admin/app';
import { getMessaging as getFirebaseMessaging, type Messaging } from 'firebase-admin/messaging';

let app: App | null = null;

/**
 * Lazy init — reads the service account path from GOOGLE_APPLICATION_CREDENTIALS
 * (see .env), resolved relative to the process cwd (k9sync-backend/). Not
 * called at module load so a missing/invalid key file only breaks push
 * sending, never server startup.
 */
export function getMessaging(): Messaging {
  if (!app) {
    app = initializeApp({ credential: applicationDefault() });
  }
  return getFirebaseMessaging(app);
}
