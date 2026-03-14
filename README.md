# K9 Sync — Collier GPS & IoT pour chiens

Projet YNOV — Application mobile Flutter + Backend Node.js/Fastify + IoT ESP32

## Stack technique

| Couche | Technologies |
|--------|-------------|
| Mobile | Flutter 3.x, Riverpod, Bloc, GoRouter, Hive, Dio |
| Backend | Node.js, Fastify, TypeScript, Prisma, PostgreSQL |
| IoT | ESP32, MQTT (Mosquitto), Neo-6M GPS, MPU6050, MLX90614 |
| Auth | JWT (access 15min + refresh 7j), bcrypt |
| Infra | Docker (PostgreSQL), Firebase FCM (push) |

## Prérequis

- Flutter 3.x (`flutter --version`)
- Node.js 20+ (`node --version`)
- PostgreSQL 15 (via Docker ou local, port 5433)
- Python 3.x (pour le simulateur collier)
- Mosquitto MQTT broker

## Lancement rapide

### 1. Base de données

```bash
# Démarrer PostgreSQL (Docker)
docker run --name k9sync-db -e POSTGRES_USER=k9sync \
  -e POSTGRES_PASSWORD=password -e POSTGRES_DB=k9sync_dev \
  -p 5433:5432 -d postgres:15

# Appliquer le schéma
cd k9sync-backend
npx prisma migrate dev
```

### 2. Backend

```bash
cd k9sync-backend
cp .env.example .env   # remplir les variables
npm install
npm run dev            # démarre sur http://localhost:3000
```

Variables `.env` essentielles :
```
DATABASE_URL=postgresql://k9sync:password@localhost:5433/k9sync_dev
JWT_ACCESS_SECRET=your_secret_min_32_chars
JWT_REFRESH_EXPIRES_DAYS=7
JWT_ACCESS_EXPIRES_IN=15m
PORT=3000
```

### 3. MQTT Broker

```bash
# macOS
brew install mosquitto && brew services start mosquitto

# Linux
sudo apt install mosquitto && sudo systemctl start mosquitto

# Windows
# Télécharger depuis https://mosquitto.org/download/
```

### 4. Simulateur collier ESP32

```bash
cd k9sync-backend
pip install paho-mqtt python-dotenv
python collar_simulator.py --dog-id <UUID_CHIEN> --duration 3600
```

> Remplacer `<UUID_CHIEN>` par l'UUID du chien créé après inscription.

### 5. Application Flutter

```bash
cd k9sync
flutter pub get

# Émulateur Android
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/v1

# Device physique (remplacer par l'IP du PC)
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:3000/v1
```

## Architecture

```
k9sync/                          # Flutter (Clean Architecture)
├── lib/
│   ├── domain/                  # Entités + interfaces (couche 1)
│   ├── application/             # Use cases (couche 2)
│   ├── infrastructure/          # Implémentations REST + Hive (couche 3)
│   └── presentation/            # UI Flutter + providers (couche 4)
│
k9sync-backend/                  # Node.js/Fastify
├── src/
│   ├── domain/entities/         # Entités TypeScript
│   ├── presentation/
│   │   ├── controllers/         # auth, dog, health, gps, activity, upload
│   │   └── routes/              # Routes Fastify
│   ├── shared/middleware/       # JWT auth
│   └── mqtt/                    # Handler MQTT collier
├── prisma/schema.prisma         # Schéma PostgreSQL
└── uploads/                     # Photos chiens (gitignored)
```

## Flux de données

```
ESP32 (capteurs)
    │ MQTT
    ▼
Mosquitto Broker
    │
    ▼
Backend Node.js ──→ PostgreSQL
    │ REST API
    ▼
Flutter App ──→ Hive (offline)
```

## Compte de test

Après `prisma migrate dev`, créer un compte via l'app ou :

```bash
curl -X POST http://localhost:3000/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"Test1234!","firstName":"Test","lastName":"User"}'
```

## Fonctionnalités MVP

- ✅ Suivi GPS temps réel + mode hors-ligne
- ✅ Surveillance santé (FC, température, activité)
- ✅ Mode chien perdu (MQTT)
- ✅ Profil chien (photo, race, poids, allergies)
- ✅ Partage multi-utilisateurs
- ✅ Alertes push (anomalies détectées)
- ✅ Conformité RGPD (consentements, export, suppression)
- ✅ Auth JWT sécurisée

## Roadmap

| Version | Cible | Nouveautés |
|---------|-------|------------|
| MVP | Validation concept | Firebase → REST, Flutter basique |
| V1 | 50-100 users | ESP32 custom, géofencing, export PDF |
| V2 | 500-1000 users | IA anomalies, journal véto, multi-users |
| V3 | 5000+ users | Microservices, ML prédictif, Premium |
