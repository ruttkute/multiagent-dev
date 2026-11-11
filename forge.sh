#!/bin/bash
# multiagent-dev — forge CLI
# Orchestrates Claude Squad (parallel) + OpenHands (autonomous)
# https://github.com/ruttkute/multiagent-dev

set -e

SELF="$0"
while [ -L "$SELF" ]; do
  LINK="$(readlink "$SELF")"
  case "$LINK" in /*) SELF="$LINK" ;; *) SELF="$(dirname "$SELF")/$LINK" ;; esac
done
FORGE_DIR="$(cd "$(dirname "$SELF")" && pwd)"
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
    run  <id> [id…]    Copy task prompts, open Claude Squad (press N, paste)
    auto <id>          Copy task prompt, start OpenHands Agent Canvas
    status             Show agent worktrees + open agent PRs
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

indent = lambda l: len(l) - len(l.lstrip(' '))
tasks, cur, in_tasks, i = [], None, False, 0
while i < len(lines):
    line = lines[i]; s = line.strip(); i += 1
    if s == 'tasks:':
        in_tasks = True; continue
    if not in_tasks or not s or s.startswith('#'):
        continue
    if s.startswith('- id:'):
        if cur: tasks.append(cur)
        cur = {'id': s[5:].strip().strip('"\''), 'mode': 'squad', 'branch': ''}
        continue
    if not cur:
        continue
    for key in ('prompt', 'mode', 'branch', 'issue'):
        if not s.startswith(f'{key}:'):
            continue
        val = s[len(key)+1:].strip()
        if val[:1] in ('>', '|'):
            # YAML block scalar: gather the more-indented lines, flatten to one line
            base, parts = indent(line), []
            while i < len(lines) and (not lines[i].strip() or indent(lines[i]) > base):
                if lines[i].strip(): parts.append(lines[i].strip())
                i += 1
            val = ' '.join(parts)
        elif key != 'prompt':
            val = re.split(r'\s+#', val)[0]
        cur[key] = val.strip('"\'')
        break

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

find_cs() {
  command -v cs 2>/dev/null || command -v claude-squad 2>/dev/null ||
    { [ -x "$FORGE_DIR/bin/cs" ] && echo "$FORGE_DIR/bin/cs"; } || true
}

copy_to_clipboard() {
  if command -v pbcopy &>/dev/null; then printf '%s' "$1" | pbcopy
  elif command -v wl-copy &>/dev/null; then printf '%s' "$1" | wl-copy
  elif command -v xclip &>/dev/null; then printf '%s' "$1" | xclip -selection clipboard
  else return 1
  fi
}

task_prompt() { get_task "$1" | grep '^prompt=' | cut -d= -f2-; }

# Claude Squad is a TUI with no non-interactive "new session" command:
# sessions are created inside it with N (new session with prompt).
cmd_run() {
  [ $# -eq 0 ] && { err "Usage: forge run <task-id> [task-id…]"; exit 1; }

  CS=$(find_cs)
  if [ -z "$CS" ]; then
    err "Claude Squad not found — run: forge install"
    exit 1
  fi

  local prompts_dir=".forge/prompts"
  mkdir -p "$prompts_dir"

  echo ""
  info "Preparing ${#@} parallel agent(s)…"
  echo ""

  local n=0
  for id in "$@"; do
    prompt=$(task_prompt "$id")
    [ -z "$prompt" ] && { err "No task with id '$id' in $CONFIG_FILE"; exit 1; }
    n=$((n + 1))
    printf '%s\n' "$prompt" > "$prompts_dir/$id.txt"
    printf "  ${CYAN}%d. %s${NC}\n  %s\n\n" "$n" "$id" "$prompt"
  done

  if [ $# -eq 1 ] && copy_to_clipboard "$prompt"; then
    ok "Prompt copied to clipboard"
  fi
  info "Prompts saved in $prompts_dir/ (one file per task)"
  echo ""
  echo "  In Claude Squad, for each task above:"
  echo "    N      new session with a prompt — paste the task's prompt, Enter"
  echo "    ↵ / o  attach to a session · ctrl-q detach · s commit & push · D kill"
  echo "  Each session gets its own git worktree and branch."
  echo ""
  read -r -p "  Press Enter to open Claude Squad… " _
  exec "$CS"
}

cmd_auto() {
  local id="$1"
  [ -z "$id" ] && { err "Usage: forge auto <task-id>"; exit 1; }

  prompt=$(task_prompt "$id")
  [ -z "$prompt" ] && { err "No task with id '$id' in $CONFIG_FILE"; exit 1; }

  echo ""
  info "Autonomous task: $id"
  echo "  $prompt"
  echo ""
  if copy_to_clipboard "$prompt"; then
    ok "Prompt copied — paste it into a new conversation in Agent Canvas"
  else
    info "Paste the prompt above into a new conversation in Agent Canvas"
  fi
  echo ""

  if command -v agent-canvas &>/dev/null; then
    exec agent-canvas
  elif [ -d "$FORGE_DIR/openhands/node_modules" ]; then
    info "Starting Agent Canvas from the bundled source (openhands/)…"
    cd "$FORGE_DIR/openhands" && exec npm run dev
  else
    err "OpenHands Agent Canvas not installed — run: forge install"
    exit 1
  fi
}

cmd_status() {
  echo ""
  info "Agent worktrees (Claude Squad sessions)"
  if git rev-parse --git-dir &>/dev/null; then
    git worktree list
  else
    warn "Not inside a git repository"
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

  # Claude Squad — built from the bundled source in claude-squad/
  if [ -n "$(find_cs)" ]; then
    ok "Claude Squad already installed"
  elif command -v go &>/dev/null; then
    info "Building Claude Squad from claude-squad/…"
    mkdir -p "$FORGE_DIR/bin"
    (cd "$FORGE_DIR/claude-squad" && go build -o "$FORGE_DIR/bin/cs" .) && ok "Claude Squad built → $FORGE_DIR/bin/cs"
    [ -w /usr/local/bin ] && ln -sf "$FORGE_DIR/bin/cs" /usr/local/bin/cs && ok "cs linked → /usr/local/bin/cs"
  else
    warn "Go 1.23+ is needed to build Claude Squad from claude-squad/"
    command -v brew &>/dev/null && echo "  Install Go: brew install go   then re-run: forge install"
  fi

  echo ""

  # OpenHands Agent Canvas — installed from the bundled source in openhands/
  local node_major
  node_major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)
  if command -v agent-canvas &>/dev/null || [ -d "$FORGE_DIR/openhands/node_modules" ]; then
    ok "OpenHands Agent Canvas already installed"
  elif [ "$node_major" -ge 24 ] && command -v uv &>/dev/null; then
    info "Installing OpenHands Agent Canvas from openhands/…"
    (cd "$FORGE_DIR/openhands" && npm install) && ok "Agent Canvas installed (start it with: forge auto <id>)"
  else
    warn "OpenHands Agent Canvas needs Node.js 24+ and uv"
    echo "  Node: https://nodejs.org   uv: https://docs.astral.sh/uv/"
    echo "  Then re-run: forge install"
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
