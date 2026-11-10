# PROJECT-CONTEXT.md — Template
# Copy this to your project root as PROJECT-CONTEXT.md and fill it in.
# Every agent prompt in this project should start with:
#   "Read PROJECT-CONTEXT.md first, then do the following:"
# This file is what makes multiagent-dev prompts reusable across any project.

---

# Project Context — [PROJECT NAME]

## Stack
- Language: [e.g. JavaScript / TypeScript / Python]
- Runtime: [e.g. Cloudflare Worker / Node 20 / Browser / Android WebView]
- Framework: [e.g. none (vanilla) / React 18 / Capacitor 6 / Express]
- Build tool: [e.g. wrangler / none / vite / webpack]
- Deploy: [e.g. bash deploy.sh → Cloudflare Pages / git push → GitHub Actions]
- Package manager: [e.g. npm / pnpm / yarn / none]

## File map
<!-- List the key files agents need to know about -->
- `[FILE]` — [what it is, e.g. "main app HTML — the only source file, do not edit src/index.html"]
- `[FILE]` — [e.g. "Cloudflare Worker — deployed via wrangler in deploy.sh"]
- `[FILE]` — [e.g. "deploy script — always use this, never deploy separately"]
- `[FILE]` — [e.g. "CSS variables — all colors defined here, never hardcode colors elsewhere"]

## Conventions
<!-- Things every agent must follow in this project -->
- [e.g. "No CSS framework — vanilla CSS only, use existing CSS variables on :root"]
- [e.g. "No new npm dependencies without explicit approval"]
- [e.g. "All JS is vanilla ES6 — no TypeScript, no imports/exports, no bundler"]
- [e.g. "Colors: always use CSS variables (--bg, --text, --accent) never hardcoded hex"]
- [e.g. "All API responses: { data: T } on success, { error: string, code: number } on failure"]

## Do not touch
<!-- Hard rules — files or patterns agents must never change -->
- `[FILE]` — [reason, e.g. "Capacitor artifact — not the source file"]
- [e.g. "Never run `npx wrangler deploy` or `git push` separately — always use deploy.sh"]
- [e.g. "Never add `console.log` to production code"]
- [e.g. "Never change the .shell height:100vh rule — this is load-bearing for the scroll architecture"]

## Existing patterns to follow
<!-- Tell agents what to imitate -->
- Error handling: [e.g. "see the handleApiError() function in app.js:143"]
- API calls: [e.g. "see the fetchUser() pattern in api.js:67 — always check resp.ok before .json()"]
- CSS components: [e.g. "new cards follow the .card pattern in styles.css:234"]
- Event handling: [e.g. "all click handlers use e.stopPropagation() first — see CLAUDE.md"]

## Known agent failure modes in this project
<!-- Add to this list as you discover them -->
- [e.g. "Agents often try to split the single HTML file into components — do not do this"]
- [e.g. "Agents add `type: module` to script tags — do not, this breaks Android WebView"]
- [e.g. "Agents hardcode colors instead of using CSS variables — always use var(--token)"]

## Environment variables
<!-- What exists, not the values -->
- `[VAR_NAME]` — [what it's for, e.g. "JWT signing secret — set in wrangler.toml"]
- `[VAR_NAME]` — [e.g. "RevenueCat API key — already in the HTML, do not change"]

## Testing / verification
- Run tests: [e.g. `npm test` / `npx vitest` / no test suite]
- Preview: [e.g. `npx wrangler dev` / open index.html in browser / `npm run dev`]
- Deploy: [e.g. `bash deploy.sh "commit message"`]
