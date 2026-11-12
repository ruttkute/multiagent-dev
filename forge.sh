#!/bin/bash
# forge — run AI coding agents in parallel or autonomously, one git worktree per task
# https://github.com/ruttkute/multiagent-dev

set -e

SELF="$0"
while [ -L "$SELF" ]; do
  LINK="$(readlink "$SELF")"
  case "$LINK" in /*) SELF="$LINK" ;; *) SELF="$(dirname "$SELF")/$LINK" ;; esac
done
FORGE_DIR="$(cd "$(dirname "$SELF")" && pwd)"
FORGE_SH="$FORGE_DIR/$(basename "$SELF")"
CONFIG_FILE="${FORGE_CONFIG:-forge.yml}"
AGENT="${FORGE_AGENT:-claude}"
AUTO_PERMISSION="${FORGE_AUTO_PERMISSION:-acceptEdits}"

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}▶${NC} $*"; }
ok()      { echo -e "${GREEN}✓${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC} $*"; }
err()     { echo -e "${RED}✗${NC} $*" >&2; }

usage() {
  cat <<EOF

  forge — parallel & autonomous AI coding agents, one git worktree per task

  USAGE
    forge <command> [args]

  COMMANDS
    run  <id> [id…]    Start each task in its own worktree + tmux window (interactive)
    auto <id> [id…]    Run each task unattended in the background; commit, push, open a PR
    status             Show task worktrees, agent state and open PRs
    logs <id>          Follow the log of an autonomous task
    clean <id>         Remove a task's worktree (its branch is kept)
    init [template]    Scaffold a forge.yml for this project
    install            Check and install dependencies

  TEMPLATES
    cloudflare-worker  Cloudflare Worker + wrangler deploy
    capacitor-app      HTML/JS app with Capacitor Android pipeline
    static-site        Plain HTML/CSS/JS with deploy script

  SETTINGS (environment variables)
    FORGE_AGENT             agent command (default: claude)
    FORGE_MODEL             default model for all tasks; overridden by forge.yml model: field
    FORGE_AUTO_PERMISSION   permission mode for forge auto (default: acceptEdits)
    FORGE_AUTO_BUDGET       max USD per autonomous task (optional)
    FORGE_BASE              branch/commit new task branches start from (default: HEAD)
    FORGE_CONFIG            config file (default: forge.yml)

  EXAMPLES
    forge init cloudflare-worker
    forge run add-endpoint add-cors
    forge auto add-tests
    forge status

EOF
}

# ── YAML helpers ────────────────────────────────────────────────────────────
# Reads a top-level scalar field from forge.yml: get_project_field model
get_project_field() {
  python3 - "$CONFIG_FILE" "$1" <<'PY'
import sys, re
config_file, key = sys.argv[1], sys.argv[2]
try:
    lines = open(config_file).readlines()
except FileNotFoundError:
    sys.exit(0)
for line in lines:
    s = line.strip()
    if s.startswith(f'{key}:') and not line.startswith(' ') and not line.startswith('\t'):
        val = s[len(key)+1:].strip().strip('"\'')
        val = re.split(r'\s+#', val)[0].strip()
        if val:
            print(val)
        break
PY
}

# Prints KEY=VALUE lines for one task; multi-line prompts are flattened to one line
get_task() {
  python3 - "$CONFIG_FILE" "$1" <<'PY'
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
        cur = {'id': s[5:].strip().strip('"\''), 'mode': 'parallel', 'branch': ''}
        continue
    if not cur:
        continue
    for key in ('prompt', 'mode', 'branch', 'issue', 'model'):
        if not s.startswith(f'{key}:'):
            continue
        val = s[len(key)+1:].strip()
        if val[:1] in ('>', '|'):
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

task_field() { get_task "$1" | grep "^$2=" | cut -d= -f2-; }

# ── Repo + worktree helpers ──────────────────────────────────────────────────
require_repo() {
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$ROOT" ]; then
    err "Run forge inside a git repository"; exit 1
  fi
  if ! git -C "$ROOT" rev-parse --verify -q HEAD >/dev/null; then
    err "The repository has no commits yet — make a first commit"; exit 1
  fi
  if [ ! -f "$CONFIG_FILE" ] && [ -f "$ROOT/$CONFIG_FILE" ]; then
    CONFIG_FILE="$ROOT/$CONFIG_FILE"
  fi
  FDIR="$ROOT/.forge"
  mkdir -p "$FDIR/worktrees" "$FDIR/prompts" "$FDIR/logs"
  local common exclude
  common="$(cd "$ROOT" && cd "$(git rev-parse --git-common-dir)" && pwd)"
  exclude="$common/info/exclude"
  mkdir -p "$common/info"
  if ! grep -qx '.forge/' "$exclude" 2>/dev/null; then
    echo '.forge/' >> "$exclude"
  fi
  local name; name="$(basename "$ROOT")"
  SESSION="forge-${name//[^A-Za-z0-9_-]/-}"
}

require_cmd() {
  if ! command -v "$1" &>/dev/null; then
    err "$1 not found — run: forge install"; exit 1
  fi
}

# Sets PROMPT and BRANCH for a task id
load_task() {
  local id="$1"
  if [[ ! "$id" =~ ^[A-Za-z0-9._-]+$ ]]; then
    err "Task id '$id' may only contain letters, digits, '.', '_' and '-'"; exit 1
  fi
  PROMPT="$(task_field "$id" prompt)"
  if [ -z "$PROMPT" ]; then
    err "Task '$id' has no prompt in $CONFIG_FILE"; exit 1
  fi
  BRANCH="$(task_field "$id" branch)"
  [ -z "$BRANCH" ] && BRANCH="forge/$id"
  # Per-task model > project-level model > FORGE_MODEL env var
  MODEL="$(task_field "$id" model)"
  [ -z "$MODEL" ] && MODEL="$(get_project_field model)"
  [ -z "$MODEL" ] && MODEL="${FORGE_MODEL:-}"
  local current; current="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
  if [ "$BRANCH" = "$current" ]; then
    err "Task '$id' uses branch '$BRANCH', which is checked out in your main folder — give it its own branch"; exit 1
  fi
  printf '%s\n' "$PROMPT" > "$FDIR/prompts/$id.txt"
}

# Creates (or reuses) the worktree for a task; prints its path
make_worktree() {
  local id="$1" branch="$2" wt="$FDIR/worktrees/$1"
  if [ ! -d "$wt" ]; then
    if git -C "$ROOT" show-ref --verify -q "refs/heads/$branch"; then
      git -C "$ROOT" worktree add -q "$wt" "$branch" >&2
    else
      git -C "$ROOT" worktree add -q -b "$branch" "$wt" "${FORGE_BASE:-HEAD}" >&2
    fi
  fi
  echo "$wt"
}

auto_running() {
  local pidfile="$FDIR/logs/$1.pid"
  [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null
}

tmux_has_window() {
  tmux has-session -t "=$SESSION" 2>/dev/null &&
    tmux list-windows -t "=$SESSION" -F '#W' 2>/dev/null | grep -qx "$1"
}

# ── Commands ─────────────────────────────────────────────────────────────────

cmd_run() {
  [ $# -eq 0 ] && { err "Usage: forge run <task-id> [task-id…]"; exit 1; }
  require_repo
  require_cmd tmux
  require_cmd "$AGENT"

  echo ""
  for id in "$@"; do
    load_task "$id"
    if tmux_has_window "$id"; then
      warn "$id is already open in tmux session $SESSION"
      continue
    fi
    local wt; wt="$(make_worktree "$id" "$BRANCH")"
    # The agent starts with the task prompt; when it exits, a shell stays open in the worktree
    local launch=(bash -c 'cd "$1"
[ -n "$4" ] && "$2" --model "$4" "$(cat "$3")" || "$2" "$(cat "$3")"
echo; echo "[forge] agent exited — you are in $1"; exec "${SHELL:-bash}"'
                  forge "$wt" "$AGENT" "$FDIR/prompts/$id.txt" "$MODEL")
    if tmux has-session -t "=$SESSION" 2>/dev/null; then
      tmux new-window -d -t "=$SESSION:" -n "$id" -c "$wt" "${launch[@]}"
    else
      tmux new-session -d -s "$SESSION" -n "$id" -c "$wt" "${launch[@]}"
    fi
    ok "$id → branch $BRANCH  ($wt)"
  done

  echo ""
  info "tmux session: $SESSION   (ctrl-b w: pick a task · ctrl-b n/p: next/prev · ctrl-b d: detach)"
  if [ -n "$TMUX" ]; then
    tmux switch-client -t "=$SESSION"
  elif [ -t 0 ] && [ -t 1 ]; then
    exec tmux attach -t "=$SESSION"
  else
    echo "  Attach with: tmux attach -t $SESSION"
  fi
}

cmd_auto() {
  [ $# -eq 0 ] && { err "Usage: forge auto <task-id> [task-id…]"; exit 1; }
  require_repo
  require_cmd "$AGENT"

  echo ""
  local base; base="$(git -C "$ROOT" rev-parse HEAD)"
  for id in "$@"; do
    load_task "$id"
    if auto_running "$id"; then
      warn "$id is already running — forge logs $id"
      continue
    fi
    local wt; wt="$(make_worktree "$id" "$BRANCH")"
    rm -f "$FDIR/logs/$id.status"
    nohup "$FORGE_SH" _auto-run "$id" "$wt" "$BRANCH" "$FDIR" "$base" "$MODEL" > "$FDIR/logs/$id.log" 2>&1 &
    echo $! > "$FDIR/logs/$id.pid"
    ok "$id running in the background → branch $BRANCH"
  done
  echo ""
  info "Follow a task: forge logs <id>   ·   Overview: forge status"
  echo "  Permission mode: $AUTO_PERMISSION (set FORGE_AUTO_PERMISSION to change)"
}

# Internal: the background job behind forge auto
cmd_auto_run() {
  local id="$1" wt="$2" branch="$3" fdir="$4" base="$5" model="${6:-}"
  local status="$fdir/logs/$id.status"
  set +e
  cd "$wt" || { echo "failed: worktree missing" > "$status"; exit 1; }

  echo "[forge] $(date '+%Y-%m-%d %H:%M:%S') start $id on $branch"
  local args=(-p "$(cat "$fdir/prompts/$id.txt")" --permission-mode "$AUTO_PERMISSION")
  [ -n "$FORGE_AUTO_BUDGET" ] && args+=(--max-budget-usd "$FORGE_AUTO_BUDGET")
  [ -n "$model" ] && args+=(--model "$model")
  "$AGENT" "${args[@]}"
  local rc=$?
  echo ""
  if [ $rc -ne 0 ]; then
    echo "[forge] agent exited with code $rc"
    echo "failed: agent exit $rc" > "$status"; exit $rc
  fi

  if [ -n "$(git status --porcelain)" ]; then
    git add -A && git commit -q -m "forge: $id" && echo "[forge] committed changes"
  fi
  if [ "$(git rev-list --count "$base"..HEAD)" = "0" ]; then
    echo "[forge] no changes made"
    echo "done: no changes" > "$status"; exit 0
  fi

  local remote; remote="$(git remote | head -1)"
  if [ -z "$remote" ]; then
    echo "done: committed on $branch (no remote)" > "$status"; exit 0
  fi
  if ! git push -q -u "$remote" "$branch"; then
    echo "failed: push to $remote" > "$status"; exit 1
  fi
  echo "[forge] pushed $branch to $remote"

  if command -v gh &>/dev/null; then
    local pr url
    pr="$(gh pr create --head "$branch" --title "forge: $id" --body-file "$fdir/prompts/$id.txt" 2>&1)"
    echo "[forge] $pr"
    url="$(echo "$pr" | grep -Eo 'https://[^ ]+' | tail -1)"
    if [ -n "$url" ]; then
      echo "done: $url" > "$status"
    else
      echo "done: pushed $branch, PR not created (see forge logs $id)" > "$status"
    fi
  else
    echo "done: pushed $branch (install gh for automatic PRs)" > "$status"
  fi
  echo "[forge] $(date '+%Y-%m-%d %H:%M:%S') finished"
}

cmd_status() {
  require_repo
  echo ""
  info "Tasks"
  local found=0 d id branch changes state
  for d in "$FDIR/worktrees"/*/; do
    if [ ! -d "$d" ]; then continue; fi
    found=1
    id="$(basename "$d")"
    branch="$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
    changes="$(git -C "$d" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    if auto_running "$id"; then
      state="auto: running"
    elif [ -f "$FDIR/logs/$id.status" ]; then
      state="auto: $(cat "$FDIR/logs/$id.status")"
    elif command -v tmux &>/dev/null && tmux_has_window "$id"; then
      state="open in tmux ($SESSION)"
    else
      state="idle"
    fi
    printf "  ${CYAN}%-22s${NC} %-28s %3s uncommitted  %s\n" "$id" "$branch" "$changes" "$state"
  done
  if [ $found -eq 0 ]; then
    echo "  (no tasks yet — forge run <id> or forge auto <id>)"
  fi

  echo ""
  info "Your open PRs"
  if command -v gh &>/dev/null; then
    gh pr list --author "@me" 2>/dev/null || echo "  (could not reach GitHub)"
  else
    warn "GitHub CLI not installed (brew install gh)"
  fi
  echo ""
}

cmd_logs() {
  [ -z "$1" ] && { err "Usage: forge logs <task-id>"; exit 1; }
  require_repo
  local log="$FDIR/logs/$1.log"
  if [ ! -f "$log" ]; then
    err "No log for '$1' — it runs with: forge auto $1"; exit 1
  fi
  if auto_running "$1"; then
    exec tail -n 50 -f "$log"
  else
    cat "$log"
  fi
}

cmd_clean() {
  [ -z "$1" ] && { err "Usage: forge clean <task-id>"; exit 1; }
  require_repo
  local id="$1" wt="$FDIR/worktrees/$1"
  if [ ! -d "$wt" ]; then
    err "No worktree for '$id'"; exit 1
  fi
  if auto_running "$id"; then
    err "$id is still running — wait for it to finish (forge logs $id)"; exit 1
  fi
  if command -v tmux &>/dev/null && tmux_has_window "$id"; then
    err "$id is open in tmux — exit the agent and close its window first"; exit 1
  fi
  if ! git -C "$ROOT" worktree remove "$wt"; then
    err "Worktree has uncommitted changes — commit or discard them in $wt first"; exit 1
  fi
  rm -f "$FDIR/logs/$id.pid" "$FDIR/logs/$id.status"
  ok "Removed worktree for $id (branch kept: git branch -D <branch> to delete it)"
}

cmd_init() {
  local template="${1:-}"

  if [ -f "forge.yml" ]; then
    err "forge.yml already exists. Delete it first to reinitialize."
    exit 1
  fi

  if [ -n "$template" ] && [ -f "$FORGE_DIR/templates/$template/forge.yml" ]; then
    cp "$FORGE_DIR/templates/$template/forge.yml" forge.yml
    ok "Created forge.yml from template: $template"
  else
    if [ -n "$template" ]; then
      warn "Template '$template' not found — using generic"
    fi
    cat > forge.yml <<YAML
# forge config — $(basename "$(pwd)")
# Docs: https://github.com/ruttkute/multiagent-dev

project: $(basename "$(pwd)")

tasks:
  # Interactive, in parallel:   forge run <id> [id…]
  # Unattended, opens a PR:     forge auto <id> [id…]

  - id: example-feature
    prompt: "Describe what you want this agent to build or fix"
    mode: parallel
    branch: feat/example

  # - id: fix-bug
  #   prompt: "Fix the login screen crash on Android 13"
  #   mode: parallel
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
  info "Checking forge dependencies"
  echo ""
  local missing=0

  for tool in git python3; do
    if command -v "$tool" &>/dev/null; then ok "$tool"; else err "$tool is required"; missing=1; fi
  done

  if command -v "$AGENT" &>/dev/null; then
    ok "$AGENT (agent)"
  else
    warn "$AGENT not found"
    if [ "$AGENT" = "claude" ]; then
      echo "  Install Claude Code: npm install -g @anthropic-ai/claude-code"
    fi
    missing=1
  fi

  for tool in tmux gh; do
    if command -v "$tool" &>/dev/null; then
      ok "$tool"
    elif command -v brew &>/dev/null; then
      info "Installing $tool…"
      if brew install "$tool"; then ok "$tool installed"; else missing=1; fi
      if [ "$tool" = "gh" ] && command -v gh &>/dev/null; then
        echo "  Sign in to GitHub: gh auth login"
      fi
    else
      warn "$tool not found — install it with your package manager"
      missing=1
    fi
  done

  echo ""
  if [ $missing -eq 0 ]; then
    ok "Ready. Next: forge init [template]"
  else
    warn "Install the missing tools above, then re-run: forge install"
  fi
  echo ""
}

# ── Router ───────────────────────────────────────────────────────────────────
case "${1:-}" in
  run)       shift; cmd_run "$@" ;;
  auto)      shift; cmd_auto "$@" ;;
  _auto-run) shift; cmd_auto_run "$@" ;;
  status)    cmd_status ;;
  logs)      shift; cmd_logs "$@" ;;
  clean)     shift; cmd_clean "$@" ;;
  init)      shift; cmd_init "$@" ;;
  install)   cmd_install ;;
  help|--help|-h|"") usage ;;
  *) err "Unknown command: $1"; usage; exit 1 ;;
esac
