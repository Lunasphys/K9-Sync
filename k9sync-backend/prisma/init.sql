-- K9 Sync — Script SQL PostgreSQL (aligné sur prisma/schema.prisma)
-- Exécuter sur une base vide (ex: k9sync_dev) après création de la DB.

-- Extension UUID (si pas déjà activée)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Users
CREATE TABLE "User" (
  "id"                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "email"             TEXT NOT NULL UNIQUE,
  "password_hash"     TEXT NOT NULL,
  "first_name"        TEXT NOT NULL,
  "last_name"         TEXT NOT NULL,
  "phone"             TEXT,
  "subscription_plan"  TEXT NOT NULL DEFAULT 'free',
  "created_at"        TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at"       TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Refresh tokens (JWT)
CREATE TABLE "RefreshToken" (
  "id"         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "user_id"    UUID NOT NULL REFERENCES "User"("id") ON DELETE CASCADE,
  "token"      TEXT NOT NULL,
  "expires_at" TIMESTAMP(3) NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX "RefreshToken_user_id_idx" ON "RefreshToken"("user_id");
CREATE INDEX "RefreshToken_expires_at_idx" ON "RefreshToken"("expires_at");

-- 3. Dogs
CREATE TABLE "Dog" (
  "id"          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "name"        TEXT NOT NULL,
  "breed"       TEXT,
  "birth_date"  TIMESTAMP(3),
  "avatar_url"  TEXT,
  "created_at"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Dog <-> User (accès)
CREATE TABLE "DogUser" (
  "id"         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "dog_id"     UUID NOT NULL REFERENCES "Dog"("id") ON DELETE CASCADE,
  "user_id"    UUID NOT NULL REFERENCES "User"("id") ON DELETE CASCADE,
  "role"       TEXT NOT NULL DEFAULT 'owner',
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE("dog_id", "user_id")
);
CREATE INDEX "DogUser_user_id_idx" ON "DogUser"("user_id");

-- 5. Collars
CREATE TABLE "Collar" (
  "id"               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "serial_number"    TEXT NOT NULL UNIQUE,
  "dog_id"           UUID NOT NULL UNIQUE REFERENCES "Dog"("id") ON DELETE CASCADE,
  "battery_level"    INT,
  "firmware_version" TEXT,
  "last_seen_at"     TIMESTAMP(3),
  "created_at"       TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at"       TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 6. GPS locations
CREATE TABLE "GpsLocation" (
  "id"          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "collar_id"   UUID NOT NULL REFERENCES "Collar"("id") ON DELETE CASCADE,
  "latitude"    DOUBLE PRECISION NOT NULL,
  "longitude"   DOUBLE PRECISION NOT NULL,
  "accuracy"    DOUBLE PRECISION,
  "recorded_at" TIMESTAMP(3) NOT NULL,
  "synced_at"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "trail_id"    TEXT
);
CREATE INDEX "GpsLocation_collar_id_recorded_at_idx" ON "GpsLocation"("collar_id", "recorded_at");
CREATE INDEX "GpsLocation_trail_id_idx" ON "GpsLocation"("trail_id");

-- 7. Trails (parcours)
CREATE TABLE "Trail" (
  "id"            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "collar_id"     UUID NOT NULL,
  "started_at"    TIMESTAMP(3) NOT NULL,
  "ended_at"      TIMESTAMP(3) NOT NULL,
  "distance_m"    INT NOT NULL,
  "duration_s"    INT NOT NULL,
  "points_count"  INT NOT NULL
);

-- 8. Health records
CREATE TABLE "HealthRecord" (
  "id"               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "collar_id"        UUID NOT NULL REFERENCES "Collar"("id") ON DELETE CASCADE,
  "heart_rate"       INT,
  "temperature"      DOUBLE PRECISION,
  "anomaly_detected" BOOLEAN NOT NULL DEFAULT false,
  "anomaly_type"     TEXT,
  "recorded_at"      TIMESTAMP(3) NOT NULL,
  "synced_at"        TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX "HealthRecord_collar_id_recorded_at_idx" ON "HealthRecord"("collar_id", "recorded_at");

-- 9. Alerts
CREATE TABLE "Alert" (
  "id"         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "dog_id"     UUID NOT NULL REFERENCES "Dog"("id") ON DELETE CASCADE,
  "type"       TEXT NOT NULL,
  "title"      TEXT NOT NULL,
  "body"       TEXT,
  "read"       BOOLEAN NOT NULL DEFAULT false,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX "Alert_dog_id_idx" ON "Alert"("dog_id");
