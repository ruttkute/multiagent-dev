# multiagent-dev

> Run multiple AI coding agents in parallel or autonomously — across any project.

`forge` gives every task its own git worktree and branch, then either:

- **opens it as an interactive agent session** in its own tmux window, so you can run many side by side and steer each one, or
- **runs it unattended** in the background, then commits, pushes and opens a pull request for you to review.

Tasks live in one `forge.yml` per project. The agent is [Claude Code](https://claude.ai/code) by default; set `FORGE_AGENT` to use another CLI agent.

---

## Why

Solo devs and small teams hit a ceiling on how fast they can ship. forge lets you:

- **Run 5–10 tasks at once.** Each task gets its own worktree and branch, so agents never touch each other's files.
- **Hand off well-defined work.** `forge auto` runs a task with no supervision and opens a PR when done.
- **Define your work once.** One YAML file per project, with the same commands everywhere.
- **Drop it into any project.** Cloudflare Workers, Capacitor apps, plain HTML sites, anything in git.

---

## How it works

```
forge.yml                 ← define tasks once
    ↓
forge run task-a task-b   ← each task: new worktree + branch + tmux window,
                            agent already started with the task's prompt
forge auto task-c         ← runs in the background → commit → push → PR
forge status              ← every task's branch, uncommitted changes, state + your open PRs
```

```
your-project/
├── forge.yml
└── .forge/                       ← created by forge, never committed
    ├── worktrees/task-a/         ← branch feat/task-a, agent 1 works here
    ├── worktrees/task-b/         ← branch feat/task-b, agent 2 works here
    ├── worktrees/task-c/         ← branch feat/task-c, unattended agent
    ├── prompts/                  ← each task's prompt
    └── logs/                     ← logs + results of forge auto
```

---

## Quick start

```bash
# 1 — Install (clones to ~/.multiagent-dev and links the forge command)
curl -fsSL https://raw.githubusercontent.com/ruttkute/multiagent-dev/main/install.sh | bash

# 2 — Go to your project (must be a git repo with at least one commit)
cd my-project

# 3 — Scaffold a config (choose your stack)
forge init cloudflare-worker   # or: capacitor-app, static-site

# 4 — Edit forge.yml, then:
forge run task-a task-b        # interactive, in parallel
forge auto task-c              # unattended, opens a PR
```

---

## forge.yml format

```yaml
project: my-app

tasks:
  - id: fix-login-bug
    prompt: >
      Fix the crash on the login screen when the user submits without a password.
      File: src/screens/Login.js — check the submit handler validation.
    mode: parallel    # parallel = forge run (interactive), auto = forge auto (unattended)
    branch: fix/login-bug

  - id: add-dark-mode
    prompt: >
      Add dark/light mode toggle to the app header.
      Use CSS variables on :root. Persist choice in localStorage.
    mode: parallel
    branch: feat/dark-mode

  - id: build-auth-api
    prompt: >
      Build a full JWT authentication API in the Cloudflare Worker:
      POST /auth/login, POST /auth/refresh, DELETE /auth/logout.
      Store sessions in KV with 24h TTL.
    mode: auto
    branch: feat/auth-api
```

- **`id`**: letters, digits, `.`, `_` and `-`. It is also the worktree and tmux window name.
- **`branch`**: optional; defaults to `forge/<id>`. An existing branch is reused; otherwise it's created from your current commit (or `FORGE_BASE`). It can't be the branch checked out in your main folder.
- **`mode`**: a reminder of how the task is meant to run. You choose with `forge run` or `forge auto`.

---

## Commands

| Command | What it does |
|---|---|
| `forge run <id> [id…]` | Creates each task's worktree and opens a tmux window there with the agent started on the prompt, then attaches |
| `forge auto <id> [id…]` | Runs each task unattended in the background; on success commits, pushes and opens a PR (with `gh`) |
| `forge status` | Every task's branch, uncommitted changes and state (open in tmux / running / done + PR link / failed), plus your open PRs |
| `forge logs <id>` | Follows the log of an autonomous task |
| `forge clean <id>` | Removes a finished task's worktree (refuses if it has uncommitted changes; the branch is kept) |
| `forge init [template]` | Scaffolds a `forge.yml` |
| `forge install` | Checks dependencies and installs tmux and gh with Homebrew if missing |

### Inside the tmux session

| Keys | Action |
|---|---|
| `ctrl-b w` | Pick a task window from a list |
| `ctrl-b n` / `ctrl-b p` | Next / previous task |
| `ctrl-b d` | Detach (agents keep running); come back with `tmux attach -t forge-<project>` |

When the agent exits, the window drops to a shell inside that task's worktree, so you can test, commit and push by hand.

---

## Settings

| Variable | Default | Purpose |
|---|---|---|
| `FORGE_AGENT` | `claude` | Agent command. `forge run` calls `<agent> "<prompt>"`; `forge auto` calls `<agent> -p "<prompt>" --permission-mode <mode>` |
| `FORGE_AUTO_PERMISSION` | `acceptEdits` | Permission mode for `forge auto`. `acceptEdits` lets the agent edit files but not run arbitrary commands. Only use `bypassPermissions` in a sandbox |
| `FORGE_AUTO_BUDGET` | (none) | Maximum USD an autonomous task may spend |
| `FORGE_BASE` | `HEAD` | Branch or commit that new task branches start from |
| `FORGE_CONFIG` | `forge.yml` | Config file path |

---

## Templates

Pre-configured `forge.yml` starters for common stacks:

```bash
forge init cloudflare-worker   # Cloudflare Worker + wrangler deploy
forge init capacitor-app       # HTML/JS app compiled to Android via Capacitor
forge init static-site         # Plain HTML/CSS/JS with deploy script
```

Each template includes real, useful task prompts you can run immediately.

---

## Requirements

| Tool | Used for | Install |
|---|---|---|
| git | Worktrees and branches | Usually pre-installed |
| [Claude Code](https://claude.ai/code) | The default agent | `npm install -g @anthropic-ai/claude-code` |
| tmux 3.0+ | One window per parallel task | `brew install tmux` |
| [GitHub CLI](https://cli.github.com) | PRs from `forge auto`, PR list in `forge status` | `brew install gh`, then `gh auth login` |
| Python 3 | forge.yml parser | Usually pre-installed |

> `forge install` checks all of these and installs what it can.

---

## Tips

**Write good prompts.** The more specific the prompt, the better the output. Include:
- Which file(s) to touch
- What the current behavior is vs what you want
- Any patterns to follow from existing code

**Use `forge run` for things you want to steer.** You can watch, adjust and redirect each agent mid-task.

**Use `forge auto` for well-defined tasks.** Unattended agents work best when the task has a clear definition of done (a test that should pass, a spec to meet, a bug to reproduce and fix).

**Keep parallel tasks on separate files.** Each agent has its own branch, but two branches that edit the same lines will conflict when you merge them.

---

## Project structure

```
multiagent-dev/
├── forge.sh                   ← the forge CLI
├── install.sh                 ← one-shot installer
├── forge.example.yml          ← full example config
├── templates/                 ← forge.yml starters per stack
├── prompts/                   ← ready-to-use prompt library
├── PROMPTING.md               ← prompt engineering guide
├── PROMPTING-ADVANCED.md      ← advanced techniques
└── PROJECT-CONTEXT.template.md
```

---

## Prompt engineering

The single biggest lever for better agent output is better prompts. A vague prompt produces vague code.

**[→ Read the full prompt engineering guide](PROMPTING.md)**

It covers the five elements every prompt needs, templates for bugs, features and refactors, how to write for parallel vs autonomous mode, and before/after examples.

**[→ Browse the prompts library](prompts/)**

Ready-to-use snippets for dark mode, JWT auth, mobile layout fixes, onboarding flows, image optimization, unit tests, refactors and more. Copy one, fill in the brackets and run it.

---

## Contributing

PRs welcome. If you add a template for a stack not covered (Next.js, Supabase, React Native, etc.), open a PR — others will find it useful.

---

MIT License © ruttkute — see [LICENSE](LICENSE).
