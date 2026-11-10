# Feature: Dark / light mode toggle

**Mode:** squad  
**When to use:** Adding theme switching to any HTML/CSS project

```yaml
- id: add-dark-mode
  mode: squad
  branch: feat/dark-mode
  prompt: >
    Add dark/light mode toggle to [FILE].

    Implementation:
    1. Define color tokens as CSS variables on :root (light values):
       --bg, --bg-surface, --text, --text-muted, --border, --accent
    2. Add a [data-theme="dark"] block on :root with dark values for each token
    3. Replace all hardcoded color values in the CSS with var(--token-name)
    4. Add a toggle button to [LOCATION e.g. top-right of the header]
       - Icon: sun ☀ for light, moon ☾ for dark (or use text labels)
       - On click: toggle data-theme="dark" on <html> element
    5. Persist the user's choice in localStorage under the key 'theme'
    6. On page load: read localStorage and apply the saved theme before paint
       (put this in a <script> in <head> to avoid flash)

    Light palette suggestion: --bg:#ffffff --text:#1a1a2e --accent:[YOUR COLOR]
    Dark palette suggestion: --bg:#0d0a1a --text:#f0ecff --accent:[YOUR COLOR]

    Do not change any layout, font sizes, or spacing — only colors.
    Do not add any external library — pure CSS variables and vanilla JS only.

    Done when: toggling the button switches themes instantly with no flash on reload.
```
