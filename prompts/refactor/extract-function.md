# Refactor: Extract duplicated logic into a shared function

**Mode:** squad  
**When to use:** The same code block appears in 3+ places; time to centralize it

```yaml
- id: extract-shared-logic
  mode: squad
  branch: refactor/extract-[name]
  prompt: >
    Refactor [FILE] to extract the duplicated [DESCRIBE LOGIC] into a shared helper.

    The logic currently appears at:
    - Line [N]: [brief description of that occurrence]
    - Line [N]: [brief description]
    - Line [N]: [brief description]

    Create a new function called [FUNCTION NAME] with signature:
    [FUNCTION NAME]([PARAM1], [PARAM2]) → [RETURN TYPE/VALUE]

    Place it at [LINE NUMBER or SECTION e.g. "above the first usage" or "in a new
    file src/utils/[name].js"].

    Replace all [N] occurrences with calls to the new function.
    The external behavior must be identical — same inputs produce same outputs.
    All existing tests must still pass.

    Do not change anything else in the file.

    Done when: the logic only exists in one place and all usages call the new function.
```
