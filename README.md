# multiagent-dev

> Run multiple AI coding agents in parallel or autonomously — across any project.

Combines **[Claude Squad](https://github.com/smtg-ai/claude-squad)** (parallel interactive agents) and **[OpenHands](https://github.com/All-Hands-AI/OpenHands)** (autonomous fire-and-forget agents) into one unified workflow with a simple YAML config file.

---

## Why

Solo devs and small teams hit a ceiling on how fast they can ship. This repo lets you:

- **Run 5–10 tasks simultaneously** — each agent works on its own git branch, no conflicts
- **Fire off autonomous tasks** — give OpenHands a task, it writes code, runs tests, opens a PR
- **Define your work in one YAML file** — same config across all your projects
- **Drop it into any project** — Cloudflare Workers, Capacitor apps, plain HTML sites, anything

---

## How it works

```
forge.yml               ← define tasks once
    ↓
forge run task-a task-b ← Claude Squad runs both in parallel, each in its own git branch
forge auto task-c       ← OpenHands works on task-c autonomously, opens PR when done
forge status            ← see running agents + open PRs
```

**Claude Squad** = parallel mode. You watch the agents work, can interrupt, steer, approve.
**OpenHands** = autonomous mode. It plans, codes, tests, opens a PR. You review and merge.

---

## Quick start

```bash
# 1 — Install
curl -fsSL https://raw.githubusercontent.com/ruttkute/multiagent-dev/main/install.sh | bash

# 2 — Go to your project
cd my-project

# 3 — Scaffold a config (choose your stack)
forge init cloudflare-worker   # or: capacitor-app, static-site

# 4 — Edit forge.yml to describe your tasks, then:
forge run task-a task-b        # run in parallel
forge auto task-c              # run autonomously
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
    mode: squad       # squad = Claude Squad (parallel), auto = OpenHands (autonomous)
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
    mode: auto        # autonomous — will open a PR when done
    branch: feat/auth-api
```

---

## Commands

| Command | What it does |
|---|---|
| `forge install` | Install Claude Squad, OpenHands, GitHub CLI, tmux |
| `forge init [template]` | Scaffold a `forge.yml` for your project |
| `forge run <id> [id…]` | Run one or more tasks in parallel (Claude Squad) |
| `forge auto <id>` | Run a task autonomously (OpenHands) |
| `forge status` | Show running agents + open agent PRs |

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
| [Claude Squad](https://github.com/smtg-ai/claude-squad) | Parallel interactive agents | `brew install smtg-ai/tap/claude-squad` |
| [OpenHands](https://github.com/All-Hands-AI/OpenHands) | Autonomous fire-and-forget agents | `pip3 install openhands-ai` |
| [Claude Code](https://claude.ai/code) | The AI engine inside Claude Squad | Required API key |
| [GitHub CLI](https://cli.github.com) | PR creation + status | `brew install gh` |
| tmux | Session management (Claude Squad) | `brew install tmux` |
| Python 3.12+ | forge.yml parser | Usually pre-installed |

> Run `forge install` to install everything in one go.

---

## How agents stay isolated

Each agent gets its own **git worktree** — a separate working copy of your repo on a different branch. They can't step on each other's files. When an agent finishes, it opens a PR. You review and merge.

```
main
├── agent/fix-login-bug    ← Agent 1 working here
├── agent/dark-mode        ← Agent 2 working here
└── agent/auth-api         ← OpenHands working here autonomously
```

---

## Tips

**Write good prompts.** The more specific the prompt, the better the output. Include:
- Which file(s) to touch
- What the current behavior is vs what you want
- Any patterns to follow from existing code

**Use `mode: squad` for things you want to steer.** Claude Squad is interactive — you can watch, adjust, and redirect agents mid-task.

**Use `mode: auto` for well-defined tasks.** OpenHands works best when the task has a clear definition of done (a test that should pass, a spec to meet, a bug to reproduce and fix).

**Run `forge status` often.** See all running agents and open PRs at a glance.

---

## Project structure

```
multiagent-dev/
├── forge.sh                   ← main CLI
├── install.sh                 ← one-shot installer
├── forge.example.yml          ← full example config
└── templates/
    ├── cloudflare-worker/
    │   └── forge.yml
    ├── capacitor-app/
    │   └── forge.yml
    └── static-site/
        └── forge.yml
```

---

## Prompt engineering

The single biggest lever for better agent output is better prompts. A vague prompt produces vague code.

**[→ Read the full prompt engineering guide](PROMPTING.md)**

It covers: the five elements every prompt needs, templates for bugs/features/refactors, how to write for parallel vs autonomous mode, and before/after examples.

**[→ Browse the prompts library](prompts/)**

Ready-to-use snippets for: dark mode, JWT auth, mobile layout fixes, onboarding flows, image optimization, unit tests, refactors, and more. Copy, fill in the brackets, run.

---

## Contributing

PRs welcome. If you add a template for a stack not covered (Next.js, Supabase, React Native, etc.), open a PR — others will find it useful.

---

## Credits

This repo wraps two excellent open-source projects:
- [Claude Squad](https://github.com/smtg-ai/claude-squad) by smtg-ai
- [OpenHands](https://github.com/All-Hands-AI/OpenHands) by All Hands AI

---

MIT License
