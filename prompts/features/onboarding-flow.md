# Feature: Onboarding flow (mobile app)

**Mode:** squad  
**When to use:** Adding a first-launch onboarding sequence to a Capacitor/mobile app

```yaml
- id: add-onboarding
  mode: squad
  branch: feat/onboarding
  prompt: >
    Add a [N]-step onboarding flow to [FILE e.g. notte_v7.html].

    Show it only on first launch — gate on localStorage key 'onboarding_complete'.
    If the key is set, skip to the main app view immediately.

    Each step:
    - Full-screen background image (use [IMAGE PATHS or describe])
    - Title text (centered, large, [FONT NAME if applicable])
    - Subtitle text (centered, smaller, 70% opacity)
    - Next button (bottom-center, pill shape)
    - Step [N] has a "Get Started" button instead of Next

    Step content:
    [STEP 1]: Title: "[TITLE]" / Subtitle: "[SUBTITLE]" / Image: [PATH]
    [STEP 2]: Title: "[TITLE]" / Subtitle: "[SUBTITLE]" / Image: [PATH]
    [STEP 3]: Title: "[TITLE]" / Subtitle: "[SUBTITLE]" / Image: [PATH]

    On "Get Started": set localStorage 'onboarding_complete' = '1', hide the
    onboarding overlay, show the main app.

    Animation: fade between steps (opacity transition, 300ms).
    Safe area: respect env(safe-area-inset-top/bottom) for notch and home bar.

    Do not change any existing app logic, routes, or CSS outside the onboarding overlay.
    The overlay should sit on top of the existing DOM, not replace it.

    Done when: first launch shows the onboarding, completing it shows the app,
    and reloading the page skips onboarding.
```
