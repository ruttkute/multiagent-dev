# Fix: Mobile layout overflow / broken grid

**Mode:** parallel  
**When to use:** Page scrolls horizontally on mobile, grid breaks wrong, elements overlap

```yaml
- id: fix-mobile-layout
  mode: parallel
  branch: fix/mobile-layout
  prompt: >
    Fix the mobile layout in [FILE e.g. index.html or styles.css] at widths below 768px.

    Current problem: [describe — e.g. ".hero-grid overflows horizontally" or
    "nav overlaps the hero section" or "cards break to 1 column too early"]

    Expected: [describe — e.g. "single column layout, no horizontal scroll, 16px side padding"]

    Changes needed:
    - Add or fix @media (max-width: 768px) rules for [affected CSS classes]
    - Use [1 column / stacked / full-width] layout on mobile

    Only change CSS — do not alter HTML structure or JavaScript.
    Do not change desktop layout (above 768px).

    Done when: a 375px viewport shows [describe correct appearance] with no horizontal scroll.
```
