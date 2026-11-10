#!/bin/bash
# multiagent-dev — forge CLI
# Orchestrates Claude Squad (parallel) + OpenHands (autonomous)
# https://github.com/ruttkute/multiagent-dev

set -e

FORGE_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${FORGE_CONFIG:-forge.yml}"

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}▶${NC} $*"; }
ok()      { echo -e "${GREEN}✓${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC} $*"; }
err()     { echo -e "${RED}✗${NC} $*" >&2; }

usage() {
  cat <<EOF

  multiagent-dev — parallel & autonomous dev orchestration

  USAGE
    forge <command> [args]

  COMMANDS
    run  <id> [id…]    Run tasks in parallel via Claude Squad
    auto <id>          Run a task autonomously via OpenHands
    status             Show running agents + open agent PRs
    init [template]    Scaffold a forge.yml for this project
    install            Install all dependencies

  TEMPLATES
    cloudflare-worker  Cloudflare Worker + wrangler deploy
    capacitor-app      HTML/JS app with Capacitor Android pipeline
    static-site        Plain HTML/CSS/JS with deploy script

  EXAMPLES
    forge install
    forge init cloudflare-worker
    forge run fix-scrollbar feat-login
    forge auto add-auth-endpoint
    forge status

EOF
}

# ── YAML task parser ─────────────────────────────────────────────────────────
# Returns KEY=VALUE lines for a task id
get_task() {
  local task_id="$1"
  python3 - "$CONFIG_FILE" "$task_id" <<'PY'
import sys, re

config_file, task_id = sys.argv[1], sys.argv[2]

try:
    lines = open(config_file).readlines()
except FileNotFoundError:
    print(f"ERROR: {config_file} not found — run: forge init", file=sys.stderr)
    sys.exit(1)

tasks, cur, in_tasks = [], None, False
for line in lines:
    s = line.strip()
    if s == 'tasks:':
        in_tasks = True; continue
    if not in_tasks:
        continue
    if s.startswith('- id:'):
        if cur: tasks.append(cur)
        cur = {'id': s[5:].strip().strip('"\''), 'mode': 'squad', 'branch': ''}
    elif cur:
        for key in ('prompt', 'mode', 'branch', 'issue'):
            if s.startswith(f'{key}:'):
                cur[key] = s[len(key)+1:].strip().strip('"\'')

if cur: tasks.append(cur)

for t in tasks:
    if t['id'] == task_id:
        for k, v in t.items(): print(f"{k}={v}")
        sys.exit(0)

print(f"ERROR: task '{task_id}' not found in {config_file}", file=sys.stderr)
sys.exit(1)
PY
}

# ── Commands ─────────────────────────────────────────────────────────────────

cmd_run() {
  [ $# -eq 0 ] && { err "Usage: forge run <task-id> [task-id…]"; exit 1; }

  CS=$(command -v cs 2>/dev/null || command -v claude-squad 2>/dev/null || true)
  if [ -z "$CS" ]; then
    err "Claude Squad not found — run: forge install"
    exit 1
  fi

  echo ""
  info "Preparing ${#@} parallel agent(s)…"
  echo ""

  # Print task summary
  for id in "$@"; do
    data=$(get_task "$id")
    prompt=$(echo "$data" | grep '^prompt=' | cut -d= -f2-)
    branch=$(echo "$data" | grep '^branch=' | cut -d= -f2-)
    [ -z "$branch" ] && branch="agent/$id"
    printf "  ${CYAN}%-20s${NC}  branch: %-30s\n  prompt: %s\n\n" "$id" "$branch" "$prompt"
  done

  info "Starting Claude Squad — each task runs in its own worktree…"
  echo ""

  # Launch Claude Squad — open one session per task
  for id in "$@"; do
    data=$(get_task "$id")
    prompt=$(echo "$data" | grep '^prompt=' | cut -d= -f2-)
    branch=$(echo "$data" | grep '^branch=' | cut -d= -f2-)
    [ -z "$branch" ] && branch="agent/$id"

    # Claude Squad: cs new --name <id> --branch <branch> --prompt "<prompt>"
    "$CS" new --name "$id" --branch "$branch" --prompt "$prompt" &
    sleep 0.5
  done

  wait
  echo ""
  ok "All agents launched. Use 'forge status' to monitor."
}

cmd_auto() {
  local id="$1"
  [ -z "$id" ] && { err "Usage: forge auto <task-id>"; exit 1; }

  if ! command -v openhands &>/dev/null; then
    err "OpenHands not found — run: forge install"
    exit 1
  fi

  data=$(get_task "$id")
  prompt=$(echo "$data" | grep '^prompt=' | cut -d= -f2-)
  branch=$(echo "$data" | grep '^branch=' | cut -d= -f2-)
  [ -z "$branch" ] && branch="agent/$id"

  echo ""
  info "Starting autonomous agent: $id"
  echo "  Prompt : $prompt"
  echo "  Branch : $branch"
  echo ""
  warn "Agent will work autonomously. Check GitHub for the PR when done."
  echo ""

  openhands --task "$prompt" --git-branch "$branch"
}

cmd_status() {
  echo ""
  info "Claude Squad sessions"
  CS=$(command -v cs 2>/dev/null || command -v claude-squad 2>/dev/null || true)
  if [ -n "$CS" ]; then
    "$CS" list 2>/dev/null || echo "  (none running)"
  else
    warn "Claude Squad not installed"
  fi

  echo ""
  info "Open agent PRs"
  if command -v gh &>/dev/null; then
    gh pr list --search "head:agent/" 2>/dev/null || echo "  (none found)"
  else
    warn "GitHub CLI not installed (brew install gh)"
  fi
  echo ""
}

cmd_init() {
  local template="${1:-}"
  local src=""

  if [ -f "forge.yml" ]; then
    err "forge.yml already exists. Delete it first to reinitialize."
    exit 1
  fi

  if [ -n "$template" ] && [ -f "$FORGE_DIR/templates/$template/forge.yml" ]; then
    src="$FORGE_DIR/templates/$template/forge.yml"
    cp "$src" forge.yml
    ok "Created forge.yml from template: $template"
  else
    if [ -n "$template" ]; then
      warn "Template '$template' not found — using generic"
    fi
    cat > forge.yml <<YAML
# multiagent-dev config — $(basename "$(pwd)")
# Docs: https://github.com/ruttkute/multiagent-dev

project: $(basename "$(pwd)")

tasks:
  # Run in parallel with Claude Squad:   forge run <id> [id…]
  # Run autonomously with OpenHands:     forge auto <id>

  - id: example-feature
    prompt: "Describe what you want this agent to build or fix"
    mode: squad
    branch: feat/example

  # - id: fix-bug
  #   prompt: "Fix the login screen crash on Android 13"
  #   mode: squad
  #   branch: fix/login-crash

  # - id: autonomous-task
  #   prompt: "Implement full OAuth2 flow for the API"
  #   mode: auto
  #   branch: feat/oauth
YAML
    ok "Created forge.yml (generic)"
    echo ""
    echo "  Available templates: cloudflare-worker  |  capacitor-app  |  static-site"
    echo "  Reinitialize:        forge init <template>"
  fi
  echo ""
  echo "  Edit forge.yml, then run: forge run <task-id>"
}

cmd_install() {
  echo ""
  info "Installing multiagent-dev dependencies"
  echo ""

  # Claude Squad
  if command -v cs &>/dev/null || command -v claude-squad &>/dev/null; then
    ok "Claude Squad already installed"
  else
    info "Installing Claude Squad…"
    if command -v brew &>/dev/null; then
      brew install smtg-ai/tap/claude-squad && ok "Claude Squad installed"
    else
      warn "Homebrew not found. Install Go first, then:"
      echo "  go install github.com/smtg-ai/claude-squad@latest"
    fi
  fi

  echo ""

  # OpenHands
  if command -v openhands &>/dev/null; then
    ok "OpenHands already installed"
  else
    info "OpenHands (autonomous agent):"
    if command -v pip3 &>/dev/null; then
      echo "  Run: pip3 install openhands-ai"
      echo "  Docs: https://github.com/All-Hands-AI/OpenHands"
      warn "OpenHands requires Docker for sandboxed execution"
    else
      warn "Python 3.12+ required. Install from:"
      echo "  https://github.com/All-Hands-AI/OpenHands"
    fi
  fi

  echo ""

  # GitHub CLI
  if command -v gh &>/dev/null; then
    ok "GitHub CLI already installed"
  else
    info "Installing GitHub CLI…"
    if command -v brew &>/dev/null; then
      brew install gh && gh auth login && ok "GitHub CLI installed"
    else
      echo "  Install from: https://cli.github.com"
    fi
  fi

  echo ""

  # tmux (required by Claude Squad)
  if command -v tmux &>/dev/null; then
    ok "tmux already installed"
  else
    info "Installing tmux (required by Claude Squad)…"
    command -v brew &>/dev/null && brew install tmux && ok "tmux installed"
  fi

  echo ""
  ok "Done! Run: forge init [template]"
  echo ""
}

# ── Router ───────────────────────────────────────────────────────────────────
case "${1:-}" in
  run)     shift; cmd_run "$@" ;;
  auto)    shift; cmd_auto "$@" ;;
  status)  cmd_status ;;
  init)    shift; cmd_init "$@" ;;
  install) cmd_install ;;
  help|--help|-h|"") usage ;;
  *) err "Unknown command: $1"; usage; exit 1 ;;
esac
