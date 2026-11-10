# Testing: Write unit tests for a module

**Mode:** auto  
**When to use:** A module has no tests and you want coverage fast

```yaml
- id: write-unit-tests
  mode: auto
  branch: test/unit-coverage
  prompt: >
    Write unit tests for [FILE e.g. src/utils/auth.js].

    Testing framework: [FRAMEWORK e.g. Vitest / Jest / Node test runner]
    Test file location: [e.g. src/utils/auth.test.js]

    Cover:
    1. Happy path: valid inputs produce correct outputs
    2. Edge cases: empty string, null, undefined, zero, empty array
    3. Error cases: invalid inputs throw or return error values
    4. Boundary values: min/max lengths, limit values

    For each exported function, write at minimum:
    - 1 happy-path test
    - 1 error/invalid-input test
    - 1 edge-case test

    Do not mock external dependencies unless they are network calls or file system —
    use real implementations where possible.
    Do not test private/internal functions — only exported ones.
    Do not change the source file.

    Aim for [80]% branch coverage (run `npx vitest --coverage` to check).

    Done when: `npm test` passes with [0] failures and coverage report shows >= [80]%.
```
