# Fix: Works in browser, broken on Android WebView

**Mode:** parallel  
**When to use:** A feature looks correct in Chrome/Safari but fails in the Android app

```yaml
- id: fix-android-webview
  mode: parallel
  branch: fix/android-webview
  prompt: >
    Read PROJECT-CONTEXT.md.
    
    This project runs in Android WebView (Chromium ~105 era, inside Capacitor).
    The following is broken on Android but works in desktop Chrome:

    BROKEN: [describe exactly what happens on Android — visual bug, JS error, missing element]
    WORKING: [describe what should happen]

    Android WebView known limitations — check if any apply here:
    - CSS grid subgrid: not supported → use regular grid or flex
    - :has() selector: not supported → use class toggling instead
    - type="module" on scripts: unreliable → use classic scripts only
    - CSS @layer: not supported → flatten the styles
    - Animated children escaping overflow:hidden: add translateZ(0) + clip-path on the wrapper
    - will-change: transform promotes to its own compositing layer, escaping parent clip
    - position:sticky inside overflow:hidden: doesn't work → restructure
    - Backdrop-filter: inconsistent → test on real device

    Diagnosis steps:
    1. Read [FILE] and identify what CSS/JS is used in the broken section
    2. Check which of the above limitations applies
    3. Fix using the WebView-compatible alternative

    Do not change desktop behavior — the fix must work on both.
    Do not use any CSS that requires Chromium 110+.

    Done when: the described behavior works correctly in an Android WebView
    (test using Chrome DevTools → More tools → Remote devices, or build and deploy).
```
