-- AlterTable
ALTER TABLE "DogUser" ADD COLUMN     "expires_at" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "PendingInvite" (
    "id" TEXT NOT NULL,
    "dog_id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "role" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3),
    "invited_by" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PendingInvite_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "PendingInvite_email_idx" ON "PendingInvite"("email");

-- CreateIndex
CREATE UNIQUE INDEX "PendingInvite_dog_id_email_key" ON "PendingInvite"("dog_id", "email");

-- AddForeignKey
ALTER TABLE "PendingInvite" ADD CONSTRAINT "PendingInvite_dog_id_fkey" FOREIGN KEY ("dog_id") REFERENCES "Dog"("id") ON DELETE CASCADE ON UPDATE CASCADE;
