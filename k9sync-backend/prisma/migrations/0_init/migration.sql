-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "first_name" TEXT NOT NULL,
    "last_name" TEXT NOT NULL,
    "phone" TEXT,
    "subscription_plan" TEXT NOT NULL DEFAULT 'free',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RefreshToken" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RefreshToken_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Dog" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "breed" TEXT,
    "birth_date" TIMESTAMP(3),
    "weight" DECIMAL(65,30),
    "sex" TEXT,
    "allergies" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "photo_url" TEXT,
    "avatar_url" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Dog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DogUser" (
    "id" TEXT NOT NULL,
    "dog_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'owner',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DogUser_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Collar" (
    "id" TEXT NOT NULL,
    "serial_number" TEXT NOT NULL,
    "dog_id" TEXT NOT NULL,
    "battery_level" INTEGER,
    "firmware_version" TEXT,
    "last_seen_at" TIMESTAMP(3),
    "is_online" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Collar_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ActivityRecord" (
    "id" TEXT NOT NULL,
    "collar_id" TEXT NOT NULL,
    "steps" INTEGER NOT NULL DEFAULT 0,
    "active_minutes" INTEGER NOT NULL DEFAULT 0,
    "rest_minutes" INTEGER NOT NULL DEFAULT 0,
    "sleep_phase" TEXT NOT NULL DEFAULT 'awake',
    "anomaly_detected" BOOLEAN NOT NULL DEFAULT false,
    "anomaly_type" TEXT,
    "recorded_at" TIMESTAMP(3) NOT NULL,
    "synced_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ActivityRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "GpsLocation" (
    "id" TEXT NOT NULL,
    "collar_id" TEXT NOT NULL,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "accuracy" DOUBLE PRECISION,
    "recorded_at" TIMESTAMP(3) NOT NULL,
    "synced_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "trail_id" TEXT,

    CONSTRAINT "GpsLocation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Trail" (
    "id" TEXT NOT NULL,
    "collar_id" TEXT NOT NULL,
    "started_at" TIMESTAMP(3) NOT NULL,
    "ended_at" TIMESTAMP(3) NOT NULL,
    "distance_m" INTEGER NOT NULL,
    "duration_s" INTEGER NOT NULL,
    "points_count" INTEGER NOT NULL,

    CONSTRAINT "Trail_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "HealthRecord" (
    "id" TEXT NOT NULL,
    "collar_id" TEXT NOT NULL,
    "heart_rate" INTEGER,
    "temperature" DOUBLE PRECISION,
    "anomaly_detected" BOOLEAN NOT NULL DEFAULT false,
    "anomaly_type" TEXT,
    "recorded_at" TIMESTAMP(3) NOT NULL,
    "synced_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "HealthRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Alert" (
    "id" TEXT NOT NULL,
    "dog_id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT,
    "read" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Alert_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "RefreshToken_user_id_idx" ON "RefreshToken"("user_id");

-- CreateIndex
CREATE INDEX "RefreshToken_expires_at_idx" ON "RefreshToken"("expires_at");

-- CreateIndex
CREATE INDEX "DogUser_user_id_idx" ON "DogUser"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "DogUser_dog_id_user_id_key" ON "DogUser"("dog_id", "user_id");

-- CreateIndex
CREATE UNIQUE INDEX "Collar_serial_number_key" ON "Collar"("serial_number");

-- CreateIndex
CREATE UNIQUE INDEX "Collar_dog_id_key" ON "Collar"("dog_id");

-- CreateIndex
CREATE INDEX "ActivityRecord_collar_id_recorded_at_idx" ON "ActivityRecord"("collar_id", "recorded_at");

-- CreateIndex
CREATE INDEX "GpsLocation_collar_id_recorded_at_idx" ON "GpsLocation"("collar_id", "recorded_at");

-- CreateIndex
CREATE INDEX "GpsLocation_trail_id_idx" ON "GpsLocation"("trail_id");

-- CreateIndex
CREATE INDEX "HealthRecord_collar_id_recorded_at_idx" ON "HealthRecord"("collar_id", "recorded_at");

-- CreateIndex
CREATE INDEX "Alert_dog_id_idx" ON "Alert"("dog_id");

-- AddForeignKey
ALTER TABLE "RefreshToken" ADD CONSTRAINT "RefreshToken_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DogUser" ADD CONSTRAINT "DogUser_dog_id_fkey" FOREIGN KEY ("dog_id") REFERENCES "Dog"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DogUser" ADD CONSTRAINT "DogUser_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Collar" ADD CONSTRAINT "Collar_dog_id_fkey" FOREIGN KEY ("dog_id") REFERENCES "Dog"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ActivityRecord" ADD CONSTRAINT "ActivityRecord_collar_id_fkey" FOREIGN KEY ("collar_id") REFERENCES "Collar"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "GpsLocation" ADD CONSTRAINT "GpsLocation_collar_id_fkey" FOREIGN KEY ("collar_id") REFERENCES "Collar"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "HealthRecord" ADD CONSTRAINT "HealthRecord_collar_id_fkey" FOREIGN KEY ("collar_id") REFERENCES "Collar"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Alert" ADD CONSTRAINT "Alert_dog_id_fkey" FOREIGN KEY ("dog_id") REFERENCES "Dog"("id") ON DELETE CASCADE ON UPDATE CASCADE;

