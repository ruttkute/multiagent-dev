# Prompts Library

Ready-to-use prompt snippets. Copy into your `forge.yml`, fill in the `[brackets]`, and run.

## Categories

| Folder | Contents |
|---|---|
| [`fixes/`](fixes/) | Common bug fix prompts |
| [`features/`](features/) | New feature addition prompts |
| [`perf/`](perf/) | Performance improvement prompts |
| [`refactor/`](refactor/) | Refactoring and cleanup prompts |
| [`testing/`](testing/) | Test writing prompts |

## How to use

1. Find a prompt that matches your task
2. Copy the `prompt:` block into your `forge.yml`
3. Replace every `[bracket]` with your specifics
4. Run it: `forge run <task-id>` (`mode: parallel`) or `forge auto <task-id>` (`mode: auto`)

Prompts with `mode: parallel` are written for interactive sessions you can steer.
Prompts with `mode: auto` are written to run unattended: they spell out the definition of done.
