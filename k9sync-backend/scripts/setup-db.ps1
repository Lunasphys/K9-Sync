# K9 Sync — Crée la base PostgreSQL via Docker et applique le schéma Prisma.
# Usage: depuis k9sync-backend : .\scripts\setup-db.ps1
# Ou: npm run db:docker

$ErrorActionPreference = "Stop"
# Dossier k9sync-backend (parent du dossier scripts)
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "1. Demarrage de PostgreSQL (Docker)..." -ForegroundColor Cyan
cmd /c "docker compose up -d postgres"
if ($LASTEXITCODE -ne 0) {
    Write-Host "   Docker ou docker compose manquant. Installe Docker Desktop ou lance PostgreSQL autrement." -ForegroundColor Red
    exit 1
}

Write-Host "2. Attente du serveur PostgreSQL (5 s)..." -ForegroundColor Cyan
Start-Sleep -Seconds 5
Write-Host "   OK." -ForegroundColor Green

# URL alignée sur docker-compose.yml (port 5433 pour éviter conflit avec PostgreSQL local)
$dbUrl = "postgresql://k9sync:password@localhost:5433/k9sync_dev"
$envFile = Join-Path $root ".env"
if (-not (Test-Path $envFile)) {
    Copy-Item (Join-Path $root ".env.example") $envFile
}
$content = Get-Content $envFile -Raw -Encoding UTF8
$content = $content -replace "DATABASE_URL=[^\r\n]*", "DATABASE_URL=$dbUrl"
[System.IO.File]::WriteAllText($envFile, $content)
Write-Host "3. .env mis a jour avec DATABASE_URL pour Docker (port 5433)." -ForegroundColor Cyan

Write-Host "4. Application du schema Prisma (db push)..." -ForegroundColor Cyan
$env:DATABASE_URL = $dbUrl
npx prisma db push
if ($LASTEXITCODE -ne 0) {
    Write-Host "   Echec prisma db push." -ForegroundColor Red
    exit 1
}
Write-Host ""
Write-Host "Termine. Base k9sync_dev prete. Lance: npm run dev" -ForegroundColor Green
