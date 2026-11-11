# Prompt Engineering for Coding Agents

> The quality of an agent's output is almost entirely determined by the quality of its prompt.
> A vague prompt produces vague code. A specific prompt produces production-ready code.

---

## The five elements of a good agent prompt

Every strong prompt has all five. Missing any one reduces quality significantly.

### 1. File location
Tell the agent exactly where to work. Don't make it guess.

```
❌  "Fix the login bug"
✓   "Fix the validation bug in src/screens/Login.js, inside the handleSubmit function"
```

### 2. Current behavior
Describe what's wrong or what currently exists. The agent can't see your screen.

```
❌  "The button doesn't work"
✓   "The Submit button at line 142 fires the API call even when the email field is empty,
     causing a 400 error from the backend"
```

### 3. Expected outcome
Describe done in concrete terms. What should a person see, or what should a test assert?

```
❌  "Make it validate properly"
✓   "Show an inline error message 'Email is required' below the email field when it's empty.
     The API call should not fire until all required fields are filled."
```

### 4. Constraints
Tell the agent what NOT to touch. This prevents it from helpfully refactoring half your codebase.

```
❌  (no constraints)
✓   "Only change the handleSubmit function and the JSX for the email field.
     Do not change the API call, the styling, or any other screen."
```

### 5. Pattern to follow
Point to an existing piece of code that does something similar. Agents imitate well.

```
❌  "Add error handling"
✓   "Follow the same error handling pattern already used for the password field at line 160.
     Use the same showError() helper and the same CSS class 'field-error'."
```

---

## Prompt templates

Copy and fill these in for your forge.yml tasks.

### Bug fix
```
Fix [describe the bug] in [file path], specifically in [function/section name].

Current behavior: [what happens now]
Expected behavior: [what should happen]

Only change [specific scope]. Do not modify [what to leave alone].
Follow the same pattern as [reference code location].

Verify by: [how to confirm it's fixed — a test, a visual check, a specific input]
```

### New feature
```
Add [feature name] to [file path].

It should: [list what it does, 2–4 bullet points]

Place it [where in the file/UI].
Follow the same [pattern/style/naming] as [existing similar feature].

Do not change [what to leave alone].

Done when: [concrete definition of done]
```

### Refactor
```
Refactor [function/section] in [file path].

Current problem: [why it needs refactoring — duplication, complexity, performance]
Goal: [what it should look like after]

Do not change the external behavior — inputs and outputs stay the same.
Do not change [related things to leave alone].

Done when: all existing tests pass and [specific improvement is measurable].
```

### Performance fix
```
Improve performance of [specific operation] in [file path].

Current: [describe the slow behavior — loading time, re-renders, memory use]
Target: [specific measurable goal]

Approach: [suggested technique if you know it, e.g. "add lazy loading", "memoize this call"]

Do not change the UI or any behavior visible to the user.
Test with: [how to measure improvement]
```

---

## Mode selection guide

### Use `mode: parallel` (`forge run` — interactive, in parallel) when:
- The task is medium complexity (< 1 day of work)
- You want to watch and potentially redirect the agent
- The task has UI/visual output you want to verify as it's built
- You're not fully sure what done looks like and want to steer
- Multiple tasks can run simultaneously without depending on each other

### Use `mode: auto` (`forge auto` — unattended) when:
- The task has a crystal-clear definition of done (a test to pass, a spec to implement)
- You don't need to watch it — you just want to review the PR
- The task is well-scoped with no ambiguity about what to touch
- It's a background task (write tests, add docs, convert images)
- You want to run it overnight or while you work on something else

---

## Writing prompts for parallel agents

When running multiple agents with `forge run`, they each work in their own git branch.
The main risk is **semantic conflicts** — agents that change the same conceptual area even if not the same line.

**Rule: parallel agents should never touch the same file.**

```yaml
# ✓ Good — completely separate concerns
tasks:
  - id: fix-nav
    prompt: "Fix the mobile nav in components/Nav.js only"
  - id: fix-footer
    prompt: "Fix the footer layout in components/Footer.js only"

# ✗ Bad — both might touch App.js or shared state
tasks:
  - id: add-auth
    prompt: "Add authentication to the app"
  - id: add-profile
    prompt: "Add user profile screen"
```

**Use a shared `contracts.md`** when agents need to agree on interfaces:

```markdown
# contracts.md — shared by all parallel agents

API_BASE = "https://api.example.com/v1"
Auth header = "Authorization: Bearer <token>"
Error format = { error: string, code: number }
```

Point every agent prompt to it: `"Follow the API contract in contracts.md at the project root."`

---

## Scaling prompt quality

**Start minimal, expand on failure.** Write a short prompt first. If the agent goes wrong, add one specific constraint addressing what went wrong. Don't front-load a 500-word prompt — agents work better with focused instructions.

**Use the existing codebase as your style guide.** Instead of describing a coding style, say: `"Follow exactly the same pattern as [existing thing]."` The agent will read the reference and infer the style.

**Add a 'do not' for every common mistake.** If you've seen an agent break something in a past run, add a `Do not X` line to future prompts for similar tasks. Build up a list over time.

**Test prompts with small tasks first.** Before giving an agent a 2-hour task, test the prompt framing with a 10-minute task to see how it interprets your style of instruction.

---

## Autonomous mode (`forge auto`): extra guidance

`forge auto` works without you watching. These rules prevent common failures:

**Always include a verification step.** Tell it how to know it's done.
```
Done when: `npm test` passes with no failures and the endpoint returns 200 on a valid request.
```

**Restrict the blast radius explicitly.**
```
Only create or modify files in src/api/. Do not touch src/ui/, package.json, or any config files.
```

**Include environment assumptions.**
```
Assume Node 20, the dependencies in package.json are already installed, and there is a
.env file with DATABASE_URL set.
```

**Never ask it to make a judgement call.** If the task has a decision point, make the decision in the prompt.
```
❌  "Choose the best auth approach"
✓   "Use JWT tokens with 24h expiry. Store them in httpOnly cookies, not localStorage."
```

---

## Prompt quality checklist

Before adding a task to forge.yml, check:

- [ ] Exact file path(s) named
- [ ] Current behavior or existing state described
- [ ] Done defined concretely (test passes / visual outcome / specific return value)
- [ ] Scope constrained (what not to touch)
- [ ] Pattern reference given (existing code to follow)
- [ ] Mode chosen correctly (parallel = interactive, auto = fire-and-forget)
- [ ] No ambiguous decision left for the agent to make

---

## Examples: bad → good

### Example 1 — Layout bug

```
❌ "Fix the mobile layout"

✓  "Fix the mobile layout on index.html at widths below 768px.
    The .hero-grid currently overflows horizontally because it uses
    'grid-template-columns: repeat(3, 1fr)' without a media query.
    Change it to 1 column below 768px by adding a @media rule.
    Only touch the .hero-grid CSS rule. Do not change any other layout.
    Done when the page has no horizontal scroll on a 375px viewport."
```

### Example 2 — New API endpoint

```
❌ "Add a user endpoint"

✓  "Add a GET /api/user/:id endpoint to src/worker/index.js.
    It should fetch the user record from the users KV namespace using the id param,
    return { id, email, createdAt } as JSON, or return { error: 'Not found' } with 404
    if the key doesn't exist.
    Follow the same pattern as the existing GET /api/subscription/:id handler at line 87.
    Only add the new route handler — do not change any existing routes or middleware.
    Done when: curl /api/user/test123 returns 404 JSON and /api/user/<valid-id> returns
    the user object."
```

### Example 3 — Refactor

```
❌ "Clean up the auth code"

✓  "Refactor the token validation logic in src/middleware/auth.js.
    The validateToken() function at line 23 currently duplicates the JWT decode call
    in three places (lines 23, 67, 102). Extract it into a single private helper
    _decodeToken(token) and call it from all three places.
    Do not change the function signatures of validateToken(), requireAuth(), or
    optionalAuth(). External behavior must be identical.
    Done when all three places use _decodeToken() and the existing tests still pass."
```

---

## Next level

**[→ PROMPTING-ADVANCED.md](PROMPTING-ADVANCED.md)** — context priming, chain-of-thought, self-verification, the 10 anti-patterns, stack-specific modifiers (Cloudflare Workers / Android WebView / vanilla JS / React), few-shot examples, prompt compression, and the master template.

**[→ PROJECT-CONTEXT.template.md](PROJECT-CONTEXT.template.md)** — the reusability system. Fill this in once per project and every prompt in the library works without customization.

---

## See also

- [`PROMPTING-ADVANCED.md`](PROMPTING-ADVANCED.md) — advanced techniques
- [`PROJECT-CONTEXT.template.md`](PROJECT-CONTEXT.template.md) — per-project reusability layer
- [`forge.example.yml`](forge.example.yml) — full config example with annotated prompts
- [`templates/`](templates/) — stack-specific starting tasks with pre-written prompts
