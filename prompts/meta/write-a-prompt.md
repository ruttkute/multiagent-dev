# Meta: Use an agent to write a better prompt

**Mode:** squad  
**When to use:** You know what you want but can't quite phrase it well

This is a prompt *about* prompting — give it to an agent to have it write a high-quality forge.yml task prompt for you.

```yaml
- id: write-prompt-for-task
  mode: squad
  branch: meta/prompt-writing
  prompt: >
    Read PROJECT-CONTEXT.md.
    Read PROMPTING.md and PROMPTING-ADVANCED.md.

    I need you to write a high-quality forge.yml task prompt for the following task:

    TASK DESCRIPTION: [describe what you want in plain language, as vaguely as you want]

    The prompt you write must:
    1. Start with "Read PROJECT-CONTEXT.md."
    2. Include exact file paths (read the project to find them)
    3. Describe the current state concretely
    4. Have a clear "Done when:" verification condition
    5. Include relevant constraints from PROMPTING-ADVANCED.md anti-patterns
    6. Be the right mode (squad for interactive, auto for autonomous)
    7. Follow the master template from PROMPTING-ADVANCED.md

    Output: a complete forge.yml task block, ready to paste and run.
    Do not implement the task — only write the prompt for it.
```
