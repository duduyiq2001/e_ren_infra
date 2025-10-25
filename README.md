# E-Ren Infrastructure

Development and deployment tooling for the E-Ren Rails application.

## Contents

- **e_ren** - CLI tool for local development and testing
- **docker-compose.yml** - Container orchestration for Rails + Postgres
- **src/e_ren_test/** - Dagger modules for CI/CD (future use)

## Quick Start

### Installation

Run the setup script to configure the `e_ren` CLI:

```bash
cd ~/projects/e_ren_infra
./setup.sh
```

Then reload your shell:

```bash
source ~/.zshrc
```

Or open a new terminal window.

### Usage

```bash
# Start development containers (auto-builds on first run)
e_ren up

# Run all tests
e_ren test

# Run specific test file
e_ren test spec/models/user_spec.rb

# Open interactive shell in Rails container
e_ren shell

# View logs
e_ren logs

# Rebuild Docker image (only if Dockerfile.dev changes)
e_ren build

# Stop containers
e_ren down
```

## How It Works

### Docker Setup

**Dockerfile.dev**:
- Installs system dependencies (build-essential, libpq-dev, etc.)
- Does NOT copy source code or run `bundle install`
- Built once, reused for all container starts

**docker-compose.yml**:
- **Rails container**: Built from Dockerfile.dev
  - Runs `bundle install` on startup (cached in `bundle_cache` volume)
  - Source code mounted from `~/projects/e_ren` - changes sync instantly!
- **Postgres container**: PostgreSQL 16 for development and test databases
- **Volumes**:
  - `bundle_cache`: Persists installed gems across restarts
  - Source mount: Live code sync, no rebuild needed

### e_ren CLI

Python script that wraps Docker Compose commands:
- Manages container lifecycle
- Executes RSpec tests inside the Rails container
- Pipes test output to your terminal in real-time
- Provides convenient shortcuts for common tasks

### Dagger (Future)

The `src/e_ren_test/` directory contains Dagger modules for CI/CD:
- Used by GitHub Actions to run tests in isolation
- Ensures reproducible builds across environments
- Currently scaffolded, will be configured when setting up CI/CD

## Architecture Decisions

**Why Docker Compose for local dev?**
- Fast: Containers stay running, no startup overhead per test
- Simple: Easy to understand and modify
- Standard: Well-documented, widely used

**Why Dagger for CI/CD?**
- Reproducible: Same container setup locally and in CI
- Composable: Reusable modules across projects
- Language-agnostic: Python SDK works alongside Rails

## Project Structure

```
e_ren_infra/
├── e_ren                    # CLI tool (Python)
├── docker-compose.yml       # Local dev containers
├── src/e_ren_test/         # Dagger modules (Python SDK)
│   └── main.py
└── README.md               # This file
```

## Troubleshooting

**"Cannot connect to Docker daemon"**
- Make sure Docker Desktop is running

**"Container not running"**
- Run `e_ren up` first

**"Port 5432 already in use"**
- Stop any local Postgres instances or change the port in docker-compose.yml

**Tests not seeing code changes**
- Volume mounts should sync automatically
- If issues persist, restart containers: `e_ren down && e_ren up`
