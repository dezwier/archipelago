# Connecting API to Railway Database

## Steps to Connect

### 1. Get Database URL from Railway

1. Go to your Railway project dashboard
2. Click on your **PostgreSQL** service
3. Go to the **Variables** tab
4. Copy the `DATABASE_URL` value (it looks like: `postgresql://user:password@host:port/dbname`)

### 2. Set Environment Variable

**Option A: Railway (Automatic - Recommended)**
- Railway automatically provides `DATABASE_URL` when you connect the database service to your API service
- In Railway dashboard:
  1. Go to your API service
  2. Click **Variables** tab
  3. Railway should auto-detect and link `DATABASE_URL` from the database service
  4. If not, manually add: `DATABASE_URL` = (copy from database service)

**Option B: Local Development (.env file)**
- Create `api/.env` file:
```bash
DATABASE_URL=postgresql://user:password@host:port/dbname
```

### 3. Install Dependencies

```bash
cd api
pip install -r requirements.txt
```

### 4. Run Database Migrations

Once you've defined your models in `app/models/models.py`, create and run migrations:

```bash
# Create a new migration
alembic revision --autogenerate -m "Initial migration"

# Apply migrations
alembic upgrade head
```

### 5. Test Connection

Start the API server:
```bash
uvicorn app.main:app --reload
```

Visit `http://localhost:8000/health` to verify it's running.

## Notes

- The API automatically reads `DATABASE_URL` from environment variables
- Railway injects this automatically when services are connected
- For local dev, use a `.env` file (make sure it's in `.gitignore`)

