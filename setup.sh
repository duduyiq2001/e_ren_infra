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
