#!/bin/bash

# E-Ren Infrastructure Setup Script
# Sets up the e_ren CLI command for local development

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_RC="$HOME/.zshrc"

echo "🚀 Setting up E-Ren infrastructure..."

# Make e_ren executable
if [ -f "$SCRIPT_DIR/e_ren" ]; then
  chmod +x "$SCRIPT_DIR/e_ren"
  echo "✅ Made e_ren executable"
else
  echo "❌ Error: e_ren script not found in $SCRIPT_DIR"
  exit 1
fi

# Check if already in PATH
if grep -q "e_ren_infra" "$SHELL_RC" 2>/dev/null; then
  echo "⚠️  e_ren_infra already in PATH (.zshrc)"
else
  # Add to PATH
  echo "" >> "$SHELL_RC"
  echo "# E-Ren CLI (added by setup.sh)" >> "$SHELL_RC"
  echo "export PATH=\"$SCRIPT_DIR:\$PATH\"" >> "$SHELL_RC"
  echo "✅ Added e_ren_infra to PATH in .zshrc"
fi

# Check if Docker is installed
echo ""
echo "🐳 Checking Docker..."
if ! command -v docker &> /dev/null; then
  echo "❌ Docker not found. Please install Docker Desktop first."
  echo "   Visit: https://www.docker.com/products/docker-desktop"
  exit 1
fi

if ! command -v docker-compose &> /dev/null; then
  echo "❌ docker-compose not found. Please install Docker Compose."
  exit 1
fi

echo "✅ Docker and docker-compose found"

# Ask user if they want to set up databases now
echo ""
echo "📊 Database Setup"
echo "Would you like to set up the databases now? (y/n)"
read -r setup_db

if [[ "$setup_db" =~ ^[Yy]$ ]]; then
  echo ""
  echo "🗄️  Setting up PostgreSQL and databases..."

  cd "$SCRIPT_DIR"

  # Start PostgreSQL container in background
  echo "Starting PostgreSQL container..."
  docker-compose up -d db

  # Wait for PostgreSQL to be ready
  echo "Waiting for PostgreSQL to be ready (this may take 10-15 seconds)..."
  sleep 10

  # Check if Postgres is actually ready
  max_attempts=30
  attempt=0
  until docker-compose exec -T db pg_isready -U postgres &> /dev/null; do
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
      echo "❌ PostgreSQL failed to start after 30 seconds"
      echo "   Check logs with: docker-compose logs db"
      exit 1
    fi
    echo "Still waiting for PostgreSQL... ($attempt/$max_attempts)"
    sleep 1
  done

  echo "✅ PostgreSQL is ready"

  # Create databases and run migrations
  echo ""
  echo "Installing gems and creating databases..."
  docker-compose run --rm rails bash -c "bundle install && rails db:prepare"

  if [ $? -eq 0 ]; then
    echo "✅ Databases created successfully:"
    echo "   - e_ren_development"
    echo "   - e_ren_test"
  else
    echo "❌ Database setup failed"
    echo "   Try running manually: docker-compose run --rm rails rails db:prepare"
    exit 1
  fi

  echo ""
  echo "🌱 Loading seed data (optional)..."
  echo "Would you like to load sample data? (y/n)"
  read -r load_seeds

  if [[ "$load_seeds" =~ ^[Yy]$ ]]; then
    docker-compose run --rm rails bash -c "bundle install && rails db:seed"
    echo "✅ Sample data loaded"
  else
    echo "⏭️  Skipping seed data (you can run 'docker-compose run --rm rails bash -c \"bundle install && rails db:seed\"' later)"
  fi
else
  echo "⏭️  Skipping database setup"
  echo ""
  echo "To set up databases later, run:"
  echo "  1. docker-compose up -d db"
  echo "  2. docker-compose run --rm rails bash -c 'bundle install && rails db:prepare'"
fi

# Source .zshrc or remind user
echo ""
echo "🎉 Setup complete!"
echo ""
echo "To use the e_ren command, run:"
echo "  source ~/.zshrc"
echo ""
echo "Or start a new terminal session."
echo ""
echo "Available commands:"
echo "  e_ren up              # Start containers"
echo "  e_ren test            # Run tests"
echo "  e_ren shell           # Open bash shell"
echo "  e_ren down            # Stop containers"
echo ""
