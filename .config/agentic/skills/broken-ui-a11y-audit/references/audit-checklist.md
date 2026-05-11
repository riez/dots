# Broken UI Audit Checklist

## Route Checklist

For every audited route, verify:
- page renders without obvious missing styles
- main heading is visible above the fold
- primary CTA is visible and clickable
- no horizontal scroll at `390px`, `768px`, or `1280px`
- no clipped labels, inputs, buttons, or cards
- no overlapping sticky headers, modals, popovers, or drawers
- no visually clipped headings or intro blocks even if metrics look valid
- no icon/input rows that look skewed, top-heavy, or left-heavy
- no obvious padding imbalance between sections, controls, and legal text
- no text that blends into the background
- no unusable listbox, dialog, or menu positioning
- no broken font fallback that destroys hierarchy

## Form Checklist

- labels remain visible and associated with fields
- helper/error text is readable and positioned correctly
- submit CTA stays visible while keyboard-only navigating
- validation errors are understandable without guessing
- focus ring remains visible on all key controls
- layout still feels balanced when viewed as a screenshot, not only as DOM nodes

## Visual Severity Guide

### Critical
- user cannot complete primary flow
- CTA is hidden, blocked, or off-screen
- form controls overlap or collapse
- modal or listbox cannot be used

### High
- major section unreadable at common viewport
- obvious overflow or clipping in primary content
- layout breaks in mobile or tablet for a key page
- composition is visibly broken: crushed spacing, misaligned groups, or disproportionate assets in a primary flow

### Medium
- spacing/hierarchy makes page confusing or sloppy
- inconsistent sizing that harms trust or scanability
- visible style regression that does not block task completion

## Browser Heuristics

Useful checks when debugging live pages:

- Compare `document.documentElement.scrollWidth` to `window.innerWidth`
- Check for fixed/sticky layers covering content near the bottom/right edges
- Inspect focused element visibility during keyboard navigation
- Verify popovers and dialogs stay inside viewport bounds
- Watch for text wrapping inside buttons, tabs, and input groups
- Always inspect a screenshot after measurements so you catch visual imbalance that metrics miss
