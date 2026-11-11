# Bundled upstream projects

This repo contains complete copies of two open-source projects. Each folder keeps its original license file.

| Folder | Source | Commit | Date | License |
|---|---|---|---|---|
| claude-squad | https://github.com/smtg-ai/claude-squad.git | `ce1ffb4392b01f38e2c4599c7c84d2a93973b138` | 2026-08-20 | AGPL-3.0 |
| openhands | https://github.com/OpenHands/OpenHands.git | `7b5aa9eb60bdef7d832743c12cabd537b44b8a41` | 2026-11-10 | MIT |

- The copies are snapshots of every tracked file at the commit above. Git history is not included.
- To update them to the latest upstream: `bash sync-upstream.sh` (or `bash sync-upstream.sh claude-squad` / `openhands`), review, then commit.
- `claude-squad/` is licensed under the GNU AGPL-3.0 (`claude-squad/LICENSE.md`). If you distribute a modified version, or run one as a network service, you must publish its source under the same license.
- `openhands/` is licensed under MIT (`openhands/LICENSE`). Upstream OpenHands is now **Agent Canvas**, a self-hosted control center that runs OpenHands, Claude Code, Codex, Gemini and other agents.
- Everything outside these two folders (forge CLI, templates, prompt guides) is MIT; see `LICENSE`.
