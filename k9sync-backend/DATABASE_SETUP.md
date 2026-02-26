# Relier PostgreSQL au backend K9 Sync

## Méthode rapide (Docker)

Avec **Docker Desktop** : `npm run db:docker` crée la base, les tables et met à jour `.env`. Puis `npm run dev`.

---

## 1. Configurer l’URL de connexion

Dans le fichier **`.env`** à la racine de `k9sync-backend`, définis **`DATABASE_URL`** avec tes infos de connexion :

```env
DATABASE_URL=postgresql://UTILISATEUR:MOT_DE_PASSE@HOTE:PORT/NOM_DE_LA_BASE
```

**Exemples :**

- Base locale, utilisateur `postgres`, mot de passe `secret`, base `k9sync_dev` :
  ```env
  DATABASE_URL=postgresql://postgres:secret@localhost:5432/k9sync_dev
  ```

- Base distante (ex. Supabase, Neon, etc.) : colle l’URL fournie par le service (elle ressemble déjà à l’exemple ci‑dessus).

- Caractères spéciaux dans le mot de passe : encode-les en URL, ou mets l’URL entre guillemets dans `.env`.

---

## 2. Créer les tables avec Prisma

Une fois `.env` sauvegardé, à la racine du backend :

```bash
cd k9sync-backend
npx prisma db push
```

Cela lit `prisma/schema.prisma` et crée ou met à jour les tables dans ta base.

**Alternative (avec historique de migrations) :**

```bash
npx prisma migrate dev --name init
```

---

## 3. Vérifier la connexion

- Générer le client Prisma (déjà fait après `npm install`) :
  ```bash
  npx prisma generate
  ```

- Lancer l’API :
  ```bash
  npm run dev
  ```

Si la base est bien joignable, tu devrais voir dans les logs : `Database connected` puis `K9 Sync API listening`.

---

## Résumé

| Étape | Action |
|-------|--------|
| 1 | Éditer `.env` → `DATABASE_URL=postgresql://...` avec tes identifiants |
| 2 | `npx prisma db push` (ou `npx prisma migrate dev --name init`) |
| 3 | `npm run dev` |
