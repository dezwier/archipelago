#!/bin/bash
# Run database migrations on Railway startup
cd /app
alembic upgrade head

