# Railway Deployment Guide

## ✅ What's Been Done

1. **Database Models Created** - All tables from `readme.md`:
   - `topics` - For grouping concepts
   - `concepts` - Core concept table with image paths
   - `languages` - Supported languages (en, fr, es, etc.)
   - `cards` - Language-specific card data
   - `users` - User accounts
   - `user_cards` - User progress tracking with SRS
   - `user_practices` - Practice session history

2. **Migrations Ready** - Initial migration file created at `api/alembic/versions/001_initial_migration.py`

3. **Auto-Migration on Deploy** - Dockerfile configured to run migrations on startup

4. **Code Pushed** - All changes committed and pushed to GitHub

## 🚀 Deploying to Railway

### Step 1: Connect GitHub Repo (if not already connected)
1. Go to Railway dashboard
2. Click **New Project** → **Deploy from GitHub repo**
3. Select `archipelago` repository
4. Railway will detect the `railway.toml` and create services

### Step 2: Connect Database Service
1. In your API service, go to **Variables** tab
2. Railway should auto-detect your PostgreSQL service
3. If not, manually add: `DATABASE_URL` = (copy from PostgreSQL service)

### Step 3: Deploy
Railway will automatically:
- Build the Docker image
- Run `alembic upgrade head` (creates all tables)
- Start the FastAPI server

### Step 4: Verify
1. Check the API service logs for "Running migrations..."
2. Visit your API URL: `https://your-api.railway.app/health`
3. Should return: `{"status": "healthy"}`

## 📝 Next Steps

Once deployed, you can:
- Add API endpoints in `api/app/api/v1/endpoints/`
- Seed initial language data
- Test the database connection

## 🔍 Troubleshooting

**Migrations not running?**
- Check Railway logs for errors
- Verify `DATABASE_URL` is set correctly
- Ensure Alembic can connect to the database

**Tables not created?**
- Check migration logs in Railway
- Manually run: `railway run alembic upgrade head` (if Railway CLI installed)

