---
name: broken-ui-a11y-audit
description: Catch visibly broken web UI and user-facing accessibility failures using live browser verification. Use when the user says the UI looks broken, styling is broken, layout is broken, responsive behavior is broken, or when you need a rendered-page smoke test instead of a best-practices review.
---

# Broken UI + A11y Audit

This skill is for finding real breakage in rendered web pages.

It is not a generic best-practices review. Start from what a user can actually see and do:
- broken layout
- missing or inconsistent styling
- overflow and clipping
- overlapping or off-screen content
- unusable mobile layouts
- dead or obscured controls
- unreadable text and contrast failures
- obvious keyboard and screen-reader failures

## Primary Rule

Always inspect the rendered UI in a live browser first. Do not start with static code review unless the page cannot be loaded.

Never stop at DOM checks alone. You must inspect screenshots or the rendered page visually and judge whether the layout actually looks coherent.

If a user provides a screenshot, treat it as primary evidence. Use it to identify visible failures even when the code structure looks acceptable.

## Audit Order

1. Identify the critical routes to inspect.
2. Load each route in a real browser.
3. Check desktop first, then tablet/mobile.
4. Capture visual breakage before discussing polish.
5. Run a quick accessibility smoke pass on the same rendered page.
6. Only after that, inspect code to trace the root cause.

## Required Visual Review

For every key route and viewport, explicitly review the rendered page for:
- clipped or off-canvas headings
- text that starts too close to an edge or loses its container rhythm
- icon, label, and input rows that feel visually unbalanced
- buttons or cards that have inconsistent height, padding, or visual weight
- legal copy, helper text, or secondary links that look truncated or crushed
- asset sizing that feels disproportionate relative to nearby text and controls
- sections where the padding rhythm collapses and the page looks unfinished even without literal overlap

These count as broken UI even if `scrollWidth === innerWidth` and no element is technically off-screen.

## What Counts As Broken UI

Treat these as high-priority defects:
- horizontal scrolling at normal viewport widths
- content cut off by viewport or parent containers
- controls overlapping other controls or text
- CTAs below sticky overlays or unreachable areas
- text on matching or near-matching backgrounds
- form fields with collapsed, tiny, or inconsistent sizing
- obvious missing styles or fallback fonts that break hierarchy
- layout jumps that make a page feel unfinished or unstable
- dialogs, popovers, and listboxes that render off-screen or behind content
- sections that become unreadable at mobile widths
- interaction states that disappear because of z-index or opacity issues

## What Counts As A11y Smoke Failures

Focus on user-facing failures, not exhaustive compliance:
- interactive elements without an accessible name
- keyboard trap or impossible keyboard flow
- hidden focus indicator on active controls
- icon-only controls with no label
- broken heading structure that makes the page hard to navigate
- form errors not announced or not associated with fields
- buttons/links that are only clickable by mouse or touch

## Browser Workflow

For each route:

1. Inspect at these widths unless the product needs others:
   - desktop: `1280x900`
   - tablet: `768x1024`
   - mobile: `390x844`
2. Record whether the page has:
   - horizontal overflow
   - clipped content
   - overlap/stacking issues
   - unreadable text
   - broken navigation or forms
3. Check the accessibility tree or snapshot for:
   - page heading
   - reachable primary actions
   - correct form labels
   - visible focus order
4. If something looks broken, gather:
   - screenshot
   - affected route and viewport
   - exact symptom
   - likely DOM/component area causing it

## Code Follow-Up

Only move into source inspection after you can describe the rendered failure precisely.

When tracing code, prefer the smallest component or layout wrapper that explains the issue. Avoid broad restyling until the failure mode is clear.

## Reporting Format

Report findings in this order:

1. Broken UI findings first, sorted by severity.
2. A11y failures second, only if they affect real use.
3. Suspected root cause and target file(s).
4. Recommended fix order.

When reporting a broken UI finding, describe the visual symptom in screen terms, not only code terms. Example: "title block clipped off the left edge and phone row loses horizontal balance on mobile," not only "wrapper overflow."

Keep each finding concrete:
- route
- viewport
- visible symptom
- user impact
- likely code location

## References

Use [references/audit-checklist.md](references/audit-checklist.md) for the page-by-page checklist and browser-side heuristics.
