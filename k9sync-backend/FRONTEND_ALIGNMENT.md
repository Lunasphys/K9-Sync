# Alignement Backend ↔ Frontend Flutter

Ce document recense les choix faits pour que l’API colle au frontend (lib/core/constants/api_constants.dart) et les **points de vigilance** par rapport au PDF « K9 Sync Complement Backend ».

---

## 1. Ce qui est aligné

| Flutter (api_constants) | Backend (ce repo) | Statut |
|-------------------------|-------------------|--------|
| Base URL `API_BASE_URL` = `.../v1` | Toutes les routes sous préfixe `/v1` | OK |
| `POST /auth/register` | `POST /v1/auth/register` | OK |
| `POST /auth/login` | `POST /v1/auth/login` | OK |
| `POST /auth/refresh` | `POST /v1/auth/refresh` | OK |
| `POST /auth/logout` | `POST /v1/auth/logout` | OK |
| `POST /auth/forgot-password` | `POST /v1/auth/forgot-password` | OK |
| Réponse auth: `user`, `accessToken`, `refreshToken` | Même forme (user avec id, email, firstName, lastName, phone, subscriptionPlan, createdAt, updatedAt) | OK |
| `IAuthRepository` + `AuthResult` (accessToken + refreshToken) | Login/register/refresh renvoient bien les deux tokens | OK |

Le frontend attend un `user` avec champs ISO dates (`createdAt`, `updatedAt`) ; le backend renvoie des chaînes ISO. Côté Flutter, s’il utilise un `UserModel.fromJson`, il faudra parser les dates.

---

## 2. Routes pas encore implémentées (stubs à ajouter)

Le PDF et le frontend prévoient les chemins suivants. Ils ne sont pas encore codés ici ; à ajouter au même format (sous `/v1`) :

- **Dogs** : `GET/POST /dogs`, `GET/PUT/DELETE /dogs/:id`, `GET/POST /dogs/:dogId/users`, `POST /dogs/:dogId/invite`, `DELETE /dogs/:dogId/users/:userId`
- **Collars** : `GET /collars/:id`, `GET /collars/:id/status`, `POST /collars/:id/lost-mode`
- **GPS** : `GET /dogs/:dogId/gps/latest`, `GET /dogs/:dogId/gps/history`, `GET /dogs/:dogId/gps/trails`, `GET /dogs/:dogId/gps/trails/:trailId`, `POST /dogs/:dogId/gps/sync`
- **Health** : `GET /dogs/:dogId/health/latest`, `history`, `activity`, `sleep`, `anomalies`, `sync`, `export`
- **Alerts** : `GET /dogs/:dogId/alerts`, `GET /dogs/:dogId/alerts/:alertId`, `POST .../read`, `POST .../read-all`
- **User** : `GET /users/me`, `PATCH /users/me`, `PUT /users/me/push-token`, `GET/PATCH /users/me/subscription`

Tous doivent être préfixés par `/v1` pour correspondre à `API_BASE_URL` du Flutter.

---

## 3. WebSocket temps réel (PDF §3)

- **Backend** : le PDF prévoit `GET /ws/dogs/:dogId/gps` (upgrade WebSocket), avec auth (JWT) et vérification d’accès au chien.
- **Flutter** : `api_constants` ne définit pas encore d’URL WebSocket. À ajouter côté app, par ex. :
  - soit une constante `WS_BASE_URL` (ex. `wss://api.k9sync.app`) et chemin `/ws/dogs/:dogId/gps?token=...` ;
  - soit dérivée de `API_BASE_URL` (remplacer `https` par `wss` et retirer `/v1` pour le chemin WS).

Ce backend ne monte pas encore le WebSocket ; à brancher quand vous ajouterez `@fastify/websocket` et le handler du PDF.

---

## 4. Critique du document PDF

**Points solides**

- Structure Clean Architecture (domain / application / infrastructure / presentation) cohérente avec le Flutter.
- Flux MQTT → PostgreSQL → FCM + WebSocket clair.
- Auth avec refresh token et rotation bien décrite.
- Jobs (rétention, trails, stats) et Docker bien cadrés.

**Points à corriger / clarifier**

1. **Préfixe des routes** : le PDF ne précise pas le préfixe `/v1`. Le frontend utilise une base `.../v1` ; l’API doit donc servir toutes les routes sous `/v1` (déjà fait pour l’auth).
2. **Réponse auth** : le PDF parle de refresh token mais ne détaille pas la forme exacte de la réponse login/register. Le Flutter attend `user` + `accessToken` + `refreshToken` ; c’est ce que le backend renvoie maintenant.
3. **Alerts** : le PDF parle d’`alerts.routes` ; le Flutter attend des alertes **par chien** : `/dogs/:dogId/alerts`. Les routes backend doivent donc être sous `/dogs/:dogId/alerts` (et non une ressource globale `/alerts`).
4. **Colliers** : le Flutter a `GET /collars/:id`, `/collars/:id/status`, `/collars/:id/lost-mode`. À prévoir explicitement dans l’API (pas seulement MQTT).
5. **Firestore vs PostgreSQL** : le frontend actuel a des datasources Firestore (MVP). En passant à ce backend, il faudra une implémentation REST des mêmes interfaces (repository/datasource) qui appelle cette API au lieu de Firestore. Les `api_constants` sont déjà cohérents avec les chemins ci‑dessus.
6. **JWT** : le squelette utilise une fonction de signature minimale. En production, utiliser une lib (ex. `jsonwebtoken`) avec RS256 ou HS256 et les mêmes `exp` / `sub` que dans le PDF.

---

## 5. Fichier Firebase Admin SDK

- À utiliser **uniquement** côté backend (FCM pour les push, pas dans l’app Flutter).
- Placer le JSON (ex. `k9sync-mvp-firebase-adminsdk-xxx.json`) dans ce projet backend, dans un dossier **non versionné** (ex. `config/`), et pointer `GOOGLE_APPLICATION_CREDENTIALS` vers ce fichier.
- Ne jamais committer ce fichier (déjà dans `.gitignore`).

---

## 6. Résumé

- **Auth** : alignée avec le Flutter (routes sous `/v1/auth`, réponses avec `user`, `accessToken`, `refreshToken`).
- **Restant** : implémenter les routes dogs, collars, gps, health, alerts, users selon la liste du §2 et le schéma Prisma, puis brancher WebSocket et MQTT comme dans le PDF. En gardant le préfixe `/v1` et les formes de réponses attendues par le frontend, tout s’emboîtera correctement.
