FROM python:3.11-slim

WORKDIR /app

# Copy only requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy only necessary files (not everything)
COPY app/ ./app/
COPY alembic/ ./alembic/
COPY alembic.ini .
COPY migrate.sh .
COPY assets/ ./assets/

# Make migrate script executable
RUN chmod +x migrate.sh || true

# Run migrations and start server
CMD sh -c "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"

