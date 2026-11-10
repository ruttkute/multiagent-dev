# Feature: Subscription paywall / free vs pro gating

**Mode:** squad  
**When to use:** Restricting features to paying users, showing upgrade prompts

```yaml
- id: add-paywall
  mode: squad
  branch: feat/paywall
  prompt: >
    Read PROJECT-CONTEXT.md.
    Read [MAIN FILE] to understand the current navigation and feature structure.

    Add subscription gating to [FEATURE NAME] in [FILE].

    The user's subscription status is available via [HOW TO CHECK —
    e.g. "the _isPro boolean set at line 45" or "await checkEntitlement('Pro')"].

    Gating behavior:
    - If user IS subscribed: show [feature] normally, no changes
    - If user is NOT subscribed:
      a. Show a "locked" state on the feature: [describe — e.g. "blurred overlay" or
         "disabled button with lock icon" or "grayed card"]
      b. When they tap the locked state: show an upgrade prompt

    Upgrade prompt:
    - [describe UI — e.g. "bottom sheet" or "modal overlay" or "inline card"]
    - Headline: "[HEADLINE]"
    - Body: "[1-2 sentence value proposition]"
    - CTA button: "[BUTTON TEXT]"
    - On CTA tap: call [PURCHASE FUNCTION e.g. openPaywall() or purchaseSubscription()]
    - X / close button: dismiss without action

    Do not change any other feature or screen.
    Do not change the subscription check logic itself — only add the UI gating.
    Follow the same overlay/modal pattern as [EXISTING MODAL IN THE FILE if any].

    Done when: a non-subscribed user sees the locked state, tapping it shows the
    upgrade prompt, and a subscribed user sees no difference.
```
