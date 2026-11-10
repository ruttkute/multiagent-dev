# Fix: Missing or broken API error handling

**Mode:** squad  
**When to use:** API calls crash the UI, errors aren't shown to users, unhandled promise rejections

```yaml
- id: fix-api-errors
  mode: squad
  branch: fix/api-error-handling
  prompt: >
    Fix error handling for the [ENDPOINT e.g. POST /api/subscribe] call in [FILE].

    Current problem: [describe — e.g. "if the API returns a non-200 status, the UI
    freezes / shows a blank screen / throws an uncaught exception"]

    Expected behavior:
    - On network error: show [error message or fallback UI]
    - On 4xx (user error): show the error message from the API response body
    - On 5xx (server error): show a generic "Something went wrong, try again" message
    - In all cases: re-enable the submit button / stop the loading spinner

    Follow the same error handling pattern as [OTHER API CALL IN THE FILE, e.g. the
    login call at line 87] — use the same error display component.

    Only change the error handling path — do not modify the happy path, the UI layout,
    or any other API call.

    Done when: simulating a 500 response shows the error message and the button is re-enabled.
```
