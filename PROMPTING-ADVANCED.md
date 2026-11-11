# Advanced Prompt Engineering for Coding Agents

> This guide assumes you've read [PROMPTING.md](PROMPTING.md).
> These techniques produce a noticeable step-change in output quality.

---

## The reusability system: PROJECT-CONTEXT.md

**This is the most important addition to any project using multiagent-dev.**

Every project is different — different files, different conventions, different failure modes.
Without a shared context file, every prompt needs to repeat the same project-specific details.
With it, any prompt from the [prompts library](prompts/) works immediately in any project.

### How it works

1. Copy [`PROJECT-CONTEXT.template.md`](PROJECT-CONTEXT.template.md) to your project root as `PROJECT-CONTEXT.md`
2. Fill it in once — stack, file map, conventions, do-not-touch rules, known failure modes
3. Start every agent prompt with this line:

```
Read PROJECT-CONTEXT.md first, then:
```

That single line gives every agent everything it needs to work correctly in your project
without you re-explaining your stack, your conventions, or your file structure each time.

### What goes in it

| Section | Why it matters |
|---|---|
| Stack | Agents make different assumptions for Node vs Cloudflare vs browser |
| File map | Prevents agents from editing the wrong file (e.g. a Capacitor artifact instead of the source) |
| Conventions | Stops agents from adding React to a vanilla project, or hardcoding colors |
| Do not touch | The hardest constraint to infer — agents can't know your architecture decisions |
| Existing patterns | Agents imitate well; point them at the right model |
| Known failure modes | Prevents repeating mistakes you've already seen |

### Reusability answer

The prompts in `prompts/` are universal templates with `[brackets]`.
PROJECT-CONTEXT.md is the per-project fill-in that makes them work without customization.

**Workflow for a new project:**
```
1. cp PROJECT-CONTEXT.template.md my-project/PROJECT-CONTEXT.md
2. Fill in the template (10–15 minutes, once)
3. forge init [template]
4. All prompts in prompts/ now work in this project
```

---

## Technique 1 — Context priming

Before every task, tell the agent which files to read and in what order.
Agents that read the right files first produce dramatically better code.

```yaml
# Without context priming
prompt: >
  Add error handling to the login form in app.js.

# With context priming
prompt: >
  Read PROJECT-CONTEXT.md first.
  Then read app.js lines 1-50 to understand the file structure.
  Then read the handleSignup() function to see the existing error handling pattern.
  
  Now: add the same error handling pattern to handleLogin() in app.js.
  [rest of prompt...]
```

### What to prime on

| Task type | Files to prime |
|---|---|
| Bug fix | The broken file + the test for it |
| New feature | The most similar existing feature + the file it goes in |
| Refactor | The file being refactored + any files that import from it |
| New API endpoint | The existing route handler + the router file |
| UI component | The most similar existing component + the CSS variables file |

### The "read first, plan second, act third" pattern

For complex tasks (> 1 hour of work), use a staged prompt:

```yaml
prompt: >
  Read PROJECT-CONTEXT.md.
  Read [FILE 1] fully.
  Read [FILE 2] lines [N]-[N].

  Before writing any code, describe in 3-5 sentences:
  - What you understand about the current state
  - What you plan to change and why
  - What you will NOT touch

  Then implement the change.
  
  Task: [describe the task]
```

This forces a planning pass before execution. It catches most wrong-direction errors before any code is written.

---

## Technique 2 — Chain-of-thought priming

Agents that reason step by step produce fewer mistakes than agents that jump straight to code.
The key is to ask for explicit reasoning *before* implementation.

```yaml
# Standard (agent jumps to code)
prompt: >
  Fix the login bug in auth.js line 47.

# Chain-of-thought (agent reasons first)
prompt: >
  Read auth.js.
  
  Step 1 — Diagnosis: Explain in plain language what the bug at line 47 is and why it happens.
  Step 2 — Impact: List every other function in the file that could be affected by your fix.
  Step 3 — Plan: Describe the exact change you'll make (one sentence).
  Step 4 — Implement: Make the change.
  Step 5 — Verify: Re-read your change and confirm it doesn't break anything named in Step 2.
```

### When to use it

- Complex bugs with unclear root cause
- Refactors that touch more than 3 functions
- Any task where "going the wrong direction" wastes significant time
- Tasks where you've seen agents make the same mistake before

### Lightweight version

For shorter tasks, a single line is enough:
```
Before writing code, state in one sentence what you understand the task to be.
```
This catches scope misunderstandings before they become code.

---

## Technique 3 — Self-verification instructions

Agents that verify their own output catch a large share of their own mistakes.
Add a verification block to every significant prompt.

```yaml
prompt: >
  [task description]

  After implementing, verify your work:
  - [ ] Re-read every line you changed
  - [ ] Confirm no hardcoded values that should be variables
  - [ ] Confirm the change works for the edge case: [specific edge case]
  - [ ] Confirm you did not modify any file listed in PROJECT-CONTEXT.md "Do not touch"
  - [ ] Run [test command] and confirm it passes

  If any check fails, fix it before finishing.
```

### Verification by task type

**For bug fixes:**
```
Verify: reproduce the original bug mentally with [specific input] and confirm
your fix prevents it. Also confirm the fix doesn't break [related functionality].
```

**For new features:**
```
Verify: trace through the full user journey — [user does X] → [what happens] →
[what they see]. Confirm each step works correctly with your implementation.
```

**For refactors:**
```
Verify: the external interface (function signatures, return values, side effects)
is identical before and after. Run existing tests if any.
```

**For UI changes:**
```
Verify: check at 375px width (mobile), 768px (tablet), and 1200px (desktop).
Confirm no layout shift, overflow, or broken spacing at any width.
```

---

## Technique 4 — Anti-patterns catalog

These are the 10 most common agent mistakes. Add the relevant prevention lines to any prompt where the mistake applies.

### 1. Scope creep
**What happens:** Agent "helpfully" refactors surrounding code, renames things, or improves unrelated functions.  
**Prevention:**
```
Only change [specific function/section]. Do not modify anything else in the file.
If you find other issues while working, note them in a comment but do not fix them.
```

### 2. Wrong file
**What happens:** Agent edits a generated/compiled file instead of the source.  
**Prevention:**
```
The source file is [FILE]. Do not edit [OTHER FILE] — it is auto-generated and will be overwritten.
```

### 3. Framework injection
**What happens:** Agent adds React, lodash, or another library to a project that doesn't use one.  
**Prevention:**
```
This project uses no framework and no build step. Do not add any import statements,
require() calls, or npm packages. All code must run directly in the browser.
```

### 4. Hardcoded values
**What happens:** Agent hardcodes colors, sizes, URLs, or strings that should reference variables.  
**Prevention:**
```
Never hardcode colors, sizes, or strings. Use the CSS variables defined in :root
for colors, the existing constants in [FILE] for strings, and env.[VAR] for secrets.
```

### 5. Broken mobile layout
**What happens:** Agent fixes desktop but breaks mobile, or vice versa.  
**Prevention:**
```
Test your change at both 375px (mobile) and 1280px (desktop).
If you add a @media rule, also check that it doesn't conflict with existing breakpoints.
```

### 6. Missing error handling
**What happens:** Agent writes happy-path code only, skipping error cases.  
**Prevention:**
```
Every async call must handle both success and failure. For network calls, handle:
network error (fetch throws), non-200 response, and malformed response body.
```

### 7. State mutation bugs
**What happens:** Agent mutates state directly instead of creating a new object, causing subtle bugs.  
**Prevention:**
```
Never mutate objects or arrays directly. Always create a new object/array.
Wrong: arr.push(x). Right: arr = [...arr, x].
Wrong: obj.key = val. Right: obj = { ...obj, key: val }.
```

### 8. Android WebView incompatibilities
**What happens:** Agent uses modern JS/CSS that works in Chrome but fails in Android WebView.  
**Prevention:**
```
This code runs in Android WebView (Chromium ~105). Do not use:
- CSS grid subgrid
- :has() selector
- ES2023+ syntax (use ES6)
- type="module" on script tags
- CSS @layer
Test all CSS in WebView-compatible mode.
```

### 9. Event listener leaks
**What happens:** Agent adds event listeners in a function that gets called multiple times, stacking duplicates.  
**Prevention:**
```
If you add an event listener, ensure it's not added multiple times.
Either add it once at initialization, use { once: true }, or remove the previous listener first.
```

### 10. Silent failures
**What happens:** Agent wraps everything in try/catch that swallows errors, making bugs invisible.  
**Prevention:**
```
Never use an empty catch block. Always either: (a) handle the error meaningfully,
(b) show it to the user, or (c) rethrow it. Never: catch(e) {}
```

---

## Technique 5 — Stack-specific modifiers

Add these blocks to prompts when working in a specific environment.

### Cloudflare Worker
```
This runs in Cloudflare Workers (V8 isolate, not Node.js).
Available: fetch, URL, Request, Response, Headers, crypto.subtle, KV, R2.
Not available: fs, path, process, Buffer (use Uint8Array), setTimeout > 30s.
Response must be a Response object — return new Response(body, { headers, status }).
```

### Android WebView (Capacitor)
```
This runs in Android WebView inside a Capacitor app.
Avoid: CSS grid subgrid, :has(), @layer, type="module" scripts, ES2023+.
Use: -webkit- prefixes on animations, transform: translateZ(0) for compositing,
overflow:hidden on containers with animated children (GPU layer escape bug).
Touch targets must be >= 44px. Use touch-action: manipulation on interactive elements.
```

### Vanilla JS (browser, no bundler)
```
No build step, no bundler, no npm. Code runs directly in a <script> tag.
No import/export, no require(), no TypeScript.
Use var or let/const (ES6 is fine). No JSX.
External libraries must be loaded via <script src="cdn-url"> before use.
```

### Node.js (Express / Fastify)
```
Node 20 LTS. Use native fetch (available since Node 18).
Error handling: always call next(err) in Express middleware, never throw.
Async routes must be wrapped: router.get('/', async (req, res, next) => { try {...} catch(e) { next(e) } })
```

### React / Next.js
```
React 18, TypeScript strict mode.
No class components — hooks only.
Side effects in useEffect with proper dependency arrays.
Never mutate state directly — always use setState or the setter from useState.
Server components (Next.js 13+): no useState/useEffect, no browser APIs.
```

---

## Technique 6 — Few-shot examples in prompts

Showing the agent what done looks like (not just describing it) dramatically improves output fidelity.
Use this for any task where style, format, or structure matters.

```yaml
prompt: >
  Add a new API endpoint to src/worker/index.js following the exact same pattern
  as the existing endpoints. Here is an example of the existing pattern:

  EXISTING (do not change this):
  ```
  case 'GET /api/health':
    return Response.json({ status: 'ok' });
  
  case 'GET /api/user':
    const user = await env.KV.get('user:' + userId, { type: 'json' });
    if (!user) return Response.json({ error: 'Not found' }, { status: 404 });
    return Response.json({ data: user });
  ```

  NEW (add this, following the same pattern exactly):
  - Route: GET /api/subscription
  - Logic: fetch env.KV.get('subscription:' + userId)
  - Success: return { data: subscription }
  - Not found: return { error: 'No subscription' } with 404
```

### When few-shot helps most

| Situation | What to show |
|---|---|
| New API endpoint | An existing endpoint from the same file |
| New UI component | The most similar existing component |
| New test | An existing test for a similar function |
| New route/page | An existing page at the same level |
| Error message copy | Existing error messages from the same UI |

---

## Technique 7 — Prompt iteration protocol

When an agent goes wrong, don't rewrite the whole prompt. Diagnose the specific failure and add one targeted line.

### Failure taxonomy

| What went wrong | Root cause | Fix to add |
|---|---|---|
| Agent changed the wrong file | Missing file constraint | `Only edit [EXACT FILE]. Do not touch any other file.` |
| Agent added a framework | No stack constraint | Add the stack-specific modifier block |
| Agent solved the wrong problem | Vague goal | Rewrite the "Expected outcome" section more concretely |
| Agent broke something else | Missing constraint | `Do not change [WHAT BROKE]. It must remain exactly as it is.` |
| Agent went off in the wrong direction | No plan-first instruction | Add: `Before writing code, state in one sentence what you understand the task to be.` |
| Output is correct but wrong style | Missing pattern reference | Add: `Follow the exact same style as [reference in the file].` |
| Agent did too much | Scope not constrained | Add: `Only change [SPECIFIC THING]. Stop after that one change.` |

### Iteration workflow

```
1. Run the agent
2. If output is wrong: identify which element is missing (from the 5 in PROMPTING.md)
3. Add one line targeting that specific gap
4. Re-run
5. Repeat until quality is acceptable
6. Save the final prompt back to forge.yml — it's now calibrated
```

Over time, your forge.yml prompts become increasingly precise because they carry the accumulated corrections from past runs.

---

## Technique 8 — Prompt compression for autonomous mode

Autonomous agents (forge auto) work best with dense, unambiguous prompts.
Too much narrative slows them down and introduces interpretation noise.

### Compress with structured format

```yaml
# Verbose (slower, more interpretation noise)
prompt: >
  I need you to add a new endpoint to the worker. The endpoint should handle
  GET requests to /api/stats. When a request comes in, you should look up the
  stats from KV using the user's ID as the key. If you find the stats object,
  return it as JSON. If you don't find anything, return a 404 response.

# Compressed (faster, less interpretation noise)
prompt: >
  Add to src/worker/index.js:
  Route: GET /api/stats
  - Read: env.KV.get('stats:' + userId, { type: 'json' })
  - 200: Response.json({ data: stats })
  - 404: Response.json({ error: 'No stats' }, { status: 404 })
  Follow pattern at: case 'GET /api/user' (line 87)
  Do not change: any other route, any middleware, wrangler.toml
  Done when: curl /api/stats returns 404 (no data) or 200 (with data)
```

### Rules for autonomous prompts
- Use imperative verbs: Add, Create, Change, Remove — not "I want you to" or "Please"
- Use `→` to show input/output: `input → expected output`
- Use `:` for key-value facts: `Route: GET /api/stats`
- Put the verification last, as a "Done when:" line
- Keep it to 100–150 words maximum

---

## Combining all techniques: the master template

This is the highest-quality prompt structure. Use it for any task above 30 minutes of work.

```yaml
- id: [task-id]
  mode: [parallel|auto]
  branch: [category/name]
  prompt: >
    Read PROJECT-CONTEXT.md.
    Read [FILE 1] [lines N-N if large].
    [Read FILE 2 if needed]

    Before writing code: state in one sentence what you understand this task to be.

    Task: [one-sentence description]

    Current state: [what exists now, specifically]
    Expected outcome: [what done looks like, concretely]

    Implementation:
    1. [step 1]
    2. [step 2]
    3. [step 3]

    Follow the pattern at: [FILE:LINE with similar existing code]

    Constraints:
    - Only change: [scope]
    - Do not touch: [what to leave alone]
    - [relevant stack modifier from the anti-patterns list]

    Verify after:
    - [ ] [specific check 1]
    - [ ] [specific check 2]
    - [ ] Run [test command] with no failures

    Done when: [concrete, self-verifiable condition]
```

---

## Quick reference

| Technique | When to add it | One-line version |
|---|---|---|
| Context priming | Always | `Read PROJECT-CONTEXT.md first.` |
| Chain-of-thought | Complex tasks | `Before coding, state what you understand this to be.` |
| Self-verification | Medium+ tasks | `After implementing, re-read every changed line.` |
| Anti-pattern: scope creep | Always | `Only change [X]. Note other issues but don't fix them.` |
| Anti-pattern: wrong file | Multi-file projects | `Source file is [X]. Do not edit [Y].` |
| Stack modifier: Android | Mobile apps | Add the WebView block |
| Stack modifier: Worker | Cloudflare | Add the Worker block |
| Few-shot | Style-sensitive tasks | Show one example of the existing pattern |
| Compression | Autonomous mode | Use structured format, < 150 words |
