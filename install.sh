#!/bin/bash
# multiagent-dev — one-shot installer
# https://github.com/ruttkute/multiagent-dev

set -e

REPO_URL="https://github.com/ruttkute/multiagent-dev"
INSTALL_DIR="${HOME}/.multiagent-dev"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${CYAN}▶${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }

echo ""
echo "  multiagent-dev installer"
echo "  ════════════════════════"
echo ""

# 1 — Clone or update the repo
if [ -d "$INSTALL_DIR/.git" ]; then
  info "Updating multiagent-dev…"
  git -C "$INSTALL_DIR" pull --ff-only
else
  info "Cloning multiagent-dev to $INSTALL_DIR…"
  git clone "$REPO_URL" "$INSTALL_DIR"
fi
ok "Repo ready at $INSTALL_DIR"
echo ""

# 2 — Make forge executable and symlink to PATH
chmod +x "$INSTALL_DIR/forge.sh"
LINK_DIR="/usr/local/bin"
if [ -w "$LINK_DIR" ]; then
  ln -sf "$INSTALL_DIR/forge.sh" "$LINK_DIR/forge"
  ok "forge command linked → $LINK_DIR/forge"
else
  warn "Cannot write to $LINK_DIR — adding to PATH manually"
  SHELL_RC="${HOME}/.zshrc"
  [ -n "$BASH_VERSION" ] && SHELL_RC="${HOME}/.bashrc"
  echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$SHELL_RC"
  ok "Added $INSTALL_DIR to PATH in $SHELL_RC"
  echo "  Restart your terminal or run: source $SHELL_RC"
fi
echo ""

# 3 — Run dependency install
info "Installing dependencies…"
"$INSTALL_DIR/forge.sh" install
echo ""

echo "  ════════════════════════"
ok "multiagent-dev installed!"
echo ""
echo "  NEXT STEPS"
echo "    cd your-project"
echo "    forge init cloudflare-worker   # or capacitor-app, static-site"
echo "    forge run <task-id>"
echo ""
echo "  DOCS: $REPO_URL"
echo ""
