-- CreateTable
CREATE TABLE "VetRecord" (
    "id" TEXT NOT NULL,
    "dog_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "done" BOOLEAN NOT NULL DEFAULT false,
    "notes" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VetRecord_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "VetRecord_dog_id_date_idx" ON "VetRecord"("dog_id", "date");

-- AddForeignKey
ALTER TABLE "VetRecord" ADD CONSTRAINT "VetRecord_dog_id_fkey" FOREIGN KEY ("dog_id") REFERENCES "Dog"("id") ON DELETE CASCADE ON UPDATE CASCADE;
