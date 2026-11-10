# Feature: JWT authentication (Cloudflare Worker)

**Mode:** auto  
**When to use:** Adding token-based auth to a Cloudflare Worker API

```yaml
- id: add-jwt-auth
  mode: auto
  branch: feat/jwt-auth
  prompt: >
    Add JWT authentication middleware to the Cloudflare Worker in [FILE e.g. src/worker/index.js].

    Requirements:
    1. Create a validateToken(request, env) helper that:
       - Reads the Authorization: Bearer <token> header
       - Verifies the JWT using env.JWT_SECRET (already set in wrangler.toml vars)
       - Returns the decoded payload on success, or null on failure
    2. Create a requireAuth(request, env, next) middleware that:
       - Calls validateToken()
       - Returns Response.json({ error: 'Unauthorized' }, { status: 401 }) if null
       - Otherwise calls next(payload)
    3. Apply requireAuth to all routes under /api/* except:
       - GET /health
       - POST /auth/login
       - POST /auth/register
    4. The token payload should be passed to route handlers as a second argument

    Follow the existing route handler pattern in the file.
    Use the Web Crypto API (available in Workers) for JWT verification — no external library.
    Use HS256 algorithm.

    Do not change any existing route logic — only add the auth wrapper.

    Done when:
    - curl /api/user without a token returns 401 JSON
    - curl /api/user with a valid token returns the existing response
    - curl /health (no token) returns 200
```
