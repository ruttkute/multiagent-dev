# multiagent-dev

> Run multiple AI coding agents in parallel or autonomously — across any project.

One repo, two complete agent tools inside it:

- **[`claude-squad/`](claude-squad/)**: the full source of [Claude Squad](https://github.com/smtg-ai/claude-squad). It runs many Claude Code (or Codex, Gemini, Aider) sessions side by side, each in its own git worktree.
- **[`openhands/`](openhands/)**: the full source of [OpenHands](https://github.com/OpenHands/OpenHands) Agent Canvas. It is a self-hosted control center where agents work on their own, locally, in Docker or on a server.

The `forge` CLI ties them together around one YAML task file and builds both tools from the source in this repo. You don't need anything from Homebrew or npm.

---

## Why

Solo devs and small teams hit a ceiling on how fast they can ship. This repo lets you:

- **Run 5–10 tasks simultaneously.** Each agent works in its own git worktree and branch, so nothing collides.
- **Hand off autonomous tasks.** Give Agent Canvas a task and it plans, codes and tests on its own.
- **Define your work in one YAML file.** Use the same config across all your projects.
- **Own the code.** Both tools live in this repo; read them, patch them, build them yourself.

---

## How it works

```
forge.yml               ← define tasks once
    ↓
forge run task-a task-b ← prints + saves the prompts, opens Claude Squad
                          (press N per task, paste the prompt → parallel sessions)
forge auto task-c       ← copies the prompt, starts Agent Canvas (paste it into a new conversation)
forge status            ← agent worktrees + open PRs
```

**Claude Squad** is the parallel mode. You watch the agents work and can interrupt, steer or approve.
**Agent Canvas (OpenHands)** is the autonomous mode. The agent works through the task on its own; you review the result.

> Claude Squad is a terminal UI. It has no command for creating a session from a script, so `forge run` gets the prompts ready and you start each session with `N`.

---

## Quick start

```bash
# 1 — Install (clones this repo to ~/.multiagent-dev and builds both tools)
curl -fsSL https://raw.githubusercontent.com/ruttkute/multiagent-dev/main/install.sh | bash

# 2 — Go to your project
cd my-project

# 3 — Scaffold a config (choose your stack)
forge init cloudflare-worker   # or: capacitor-app, static-site

# 4 — Edit forge.yml to describe your tasks, then:
forge run task-a task-b        # parallel (Claude Squad)
forge auto task-c              # autonomous (Agent Canvas)
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
    mode: squad       # squad = Claude Squad (parallel), auto = Agent Canvas (autonomous)
    branch: fix/login-bug

  - id: add-dark-mode
    prompt: >
      Add dark/light mode toggle to the app header.
      Use CSS variables on :root. Persist choice in localStorage.
    mode: squad
    branch: feat/dark-mode

  - id: build-auth-api
    prompt: >
      Build a full JWT authentication API in the Cloudflare Worker:
      POST /auth/login, POST /auth/refresh, DELETE /auth/logout.
      Store sessions in KV with 24h TTL.
    mode: auto
    branch: feat/auth-api
```

`branch` is a label for your own tracking. Claude Squad names each session's branch itself, using the `branch_prefix` in `~/.claude-squad/config.json`.

---

## Commands

| Command | What it does |
|---|---|
| `forge install` | Build Claude Squad from `claude-squad/`, install Agent Canvas from `openhands/`, check GitHub CLI + tmux |
| `forge init [template]` | Scaffold a `forge.yml` for your project |
| `forge run <id> [id…]` | Print the task prompts, save them to `.forge/prompts/`, open Claude Squad |
| `forge auto <id>` | Copy the task prompt to the clipboard and start Agent Canvas |
| `forge status` | Show agent git worktrees and open agent PRs |

### Inside Claude Squad

| Key | Action |
|---|---|
| `N` | New session with a prompt (paste a task's prompt) |
| `n` | New session without a prompt |
| `↵` / `o` | Attach to the selected session · `ctrl-q` to detach |
| `s` | Commit and push the session's branch |
| `c` / `r` | Checkout (pause) / resume a session |
| `D` | Kill the selected session |
| `tab` | Switch between preview and diff |

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

| Tool | Used for | How it's installed |
|---|---|---|
| Go 1.23+ | Building Claude Squad from `claude-squad/` | `brew install go` |
| Node.js 24+ and [uv](https://docs.astral.sh/uv/) | Running Agent Canvas from `openhands/` | nodejs.org, `brew install uv` |
| [Claude Code](https://claude.ai/code) | The default agent inside Claude Squad | Needs an Anthropic account |
| tmux | Session management for Claude Squad | `brew install tmux` |
| [GitHub CLI](https://cli.github.com) | PR status | `brew install gh` |
| Python 3 | forge.yml parser | Usually pre-installed |

> `forge install` builds and installs everything it can, and tells you what's missing.

---

## How agents stay isolated

Each Claude Squad session gets its own **git worktree**: a separate working copy of your repo on its own branch. Agents can't step on each other's files. Press `s` in Claude Squad to commit and push a session's branch, then open a PR and merge.

```
main
├── <prefix>/fix-login-bug    ← session 1
├── <prefix>/dark-mode        ← session 2
└── <prefix>/auth-api         ← session 3
```

---

## Updating the bundled tools

Both folders are snapshots of upstream. [`UPSTREAM.md`](UPSTREAM.md) records the exact commits. To pull the latest:

```bash
bash sync-upstream.sh          # both
bash sync-upstream.sh openhands
git diff --cached --stat       # review, then commit
```

Syncing replaces each folder with upstream's version, so any local patches inside `claude-squad/` or `openhands/` must be re-applied.

---

## Tips

**Write good prompts.** The more specific the prompt, the better the output. Include:
- Which file(s) to touch
- What the current behavior is vs what you want
- Any patterns to follow from existing code

**Use `mode: squad` for things you want to steer.** Claude Squad is interactive: you can watch, adjust and redirect agents mid-task.

**Use `mode: auto` for well-defined tasks.** Autonomous agents work best when the task has a clear definition of done (a test that should pass, a spec to meet, a bug to reproduce and fix).

---

## Project structure

```
multiagent-dev/
├── forge.sh                   ← forge CLI
├── install.sh                 ← one-shot installer
├── sync-upstream.sh           ← refresh claude-squad/ and openhands/ from upstream
├── UPSTREAM.md                ← upstream sources, commits, licenses
├── forge.example.yml          ← full example config
├── claude-squad/              ← Claude Squad source (Go, AGPL-3.0)
├── openhands/                 ← OpenHands Agent Canvas source (TypeScript, MIT)
├── templates/                 ← forge.yml starters per stack
├── prompts/                   ← ready-to-use prompt library
├── PROMPTING.md               ← prompt engineering guide
└── PROMPTING-ADVANCED.md      ← advanced techniques
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

## Credits and licenses

- [Claude Squad](https://github.com/smtg-ai/claude-squad) by smtg-ai: `claude-squad/`, AGPL-3.0
- [OpenHands](https://github.com/OpenHands/OpenHands) by the OpenHands contributors: `openhands/`, MIT
- Everything else in this repo: MIT. See [LICENSE](LICENSE) and [UPSTREAM.md](UPSTREAM.md).
