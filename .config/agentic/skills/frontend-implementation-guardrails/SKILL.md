---
name: frontend-implementation-guardrails
description: Use when implementing or refactoring frontend components, pages, styling, forms, or UI behavior in an existing application where consistency, accessibility, responsive behavior, and verification must be preserved.
user-invocable: false
---

# Frontend Implementation Guardrails

**Documentation hierarchy:** project conventions and design-system rules come first. This skill holds reusable frontend implementation procedures. If a project rule conflicts with this skill, follow the project rule and align this skill later.

Use this skill for existing-product frontend work. For blank-slate visual exploration, load `frontend-design`. For broken rendered pages, load `broken-ui-a11y-audit`.

## Core workflow

1. Inspect the current frontend structure before editing.
2. Reuse the existing framework, component primitives, design tokens, and state/data patterns.
3. Keep changes narrow and local to the requested task.
4. Load extra skills only when the task truly needs them.
5. Verify the UI change with project validators before finishing.

## Guardrails

- Match existing naming, file layout, and component patterns.
- Check that a library is already present before introducing it.
- Prefer extending existing components over creating parallel variants.
- If touching async UI, preserve loading, empty, error, and success states.
- Preserve keyboard access, focus visibility, labels, and semantic structure.
- Preserve responsive behavior; avoid desktop-only layouts unless explicitly requested.
- Use existing tokens, utility classes, or theme variables instead of hardcoded one-off styling when the codebase already has a system.
- Do not silently rewrite unrelated UI or restyle unaffected areas.

## Load these skills only when needed

- `frontend-design` for new UI surfaces or when the requested aesthetic is unclear.
- `responsive-design` when layout, breakpoints, or fluid sizing are part of the task.
- `accessibility-a11y` when adding or changing interactive controls, forms, dialogs, or navigation.
- `shadcn-ui` when the codebase uses shadcn/ui components.
- `vercel-react-best-practices` for React or Next.js rendering, composition, and performance-sensitive changes.
- `broken-ui-a11y-audit` when the issue is visible in the browser or needs rendered-page validation.

## Verification

Before completing frontend work:

1. Run the repository validators relevant to the touched files.
2. Include lint, typecheck, and tests when the project provides them.
3. Do a rendered smoke check for user-facing UI changes when practical.
4. Report the files changed and the exact validation commands run.
