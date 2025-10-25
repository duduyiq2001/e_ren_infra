# E-Ren Setup for Windows (x86_64)

This guide is for Windows developers working on E-Ren.

## Prerequisites

1. **Docker Desktop for Windows**
   - Download: https://www.docker.com/products/docker-desktop/
   - Enable WSL 2 backend (recommended)

2. **Python 3.8+**
   - Download: https://www.python.org/downloads/
   - Make sure to check "Add Python to PATH" during installation

3. **Git for Windows**
   - Download: https://git-scm.com/download/win

## Installation

1. Clone the repositories:
```bash
cd C:\Users\YourName\Projects
git clone <e_ren_repo>
git clone <e_ren_infra_repo>
```

2. Run setup (in PowerShell or Git Bash):
```bash
cd e_ren_infra
python setup.py  # Will create e_ren command
```

3. Add to PATH (PowerShell):
```powershell
$env:Path += ";C:\Users\YourName\Projects\e_ren_infra"
```

Or manually add `C:\Users\YourName\Projects\e_ren_infra` to your PATH.

## Usage

**Important:** Windows/Intel uses x86_64 architecture, so force the platform:

```bash
# Start containers (MUST specify platform for Windows)
python e_ren up --platform amd64

# Or if e_ren is in PATH:
e_ren up --platform amd64

# Run tests
e_ren test

# Open shell
e_ren shell

# Stop
e_ren down
```

## Why `--platform amd64`?

- Your Windows machine: **x86_64 (amd64)** architecture
- Mac teammates: **ARM64** architecture
- Production (AWS Graviton): **ARM64** architecture

By specifying `--platform amd64`, you build images compatible with your Windows system.

## Troubleshooting

### "Docker daemon is not running"
→ Start Docker Desktop

### "DOCKER_DEFAULT_PLATFORM: command not found"
→ Use PowerShell or Git Bash, not CMD

### Slow builds
→ Enable WSL 2 backend in Docker Desktop settings
→ Allocate more resources (Settings → Resources)

### "e_ren: command not found"
→ Use `python e_ren` instead
→ Or add e_ren_infra directory to PATH

## Architecture Note

**You build:** x86_64 (amd64) images for local development
**Production uses:** ARM64 (AWS Graviton) - CI/CD rebuilds for ARM in GitHub Actions

This is normal! Each developer builds for their own architecture.
