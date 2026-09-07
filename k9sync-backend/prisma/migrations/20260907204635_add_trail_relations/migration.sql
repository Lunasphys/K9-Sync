-- CreateIndex
CREATE INDEX "Trail_collar_id_started_at_idx" ON "Trail"("collar_id", "started_at");

-- AddForeignKey
ALTER TABLE "GpsLocation" ADD CONSTRAINT "GpsLocation_trail_id_fkey" FOREIGN KEY ("trail_id") REFERENCES "Trail"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Trail" ADD CONSTRAINT "Trail_collar_id_fkey" FOREIGN KEY ("collar_id") REFERENCES "Collar"("id") ON DELETE CASCADE ON UPDATE CASCADE;
