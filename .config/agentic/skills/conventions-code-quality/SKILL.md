---
name: conventions-code-quality
description: Code quality evaluation framework. Load during code reviews, refactoring, or quality assessment. References 8 convention documents.
---

# Code Quality Conventions

> Source of truth: ~/.config/agentic/conventions/code-quality/
> This skill provides the evaluation framework. Individual docs are read on-demand.

## Documents (read the ones relevant to your review)

| Doc | Focus | Read when |
|-----|-------|-----------|
| `01-naming-and-types.md` | Names, type annotations, clarity | Reviewing naming or type issues |
| `02-structure-and-composition.md` | File structure, function decomposition | Reviewing organization |
| `03-patterns-and-idioms.md` | Language idioms, design patterns | Reviewing pattern usage |
| `04-repetition-and-consistency.md` | DRY, consistent style | Reviewing duplication |
| `05-documentation-and-tests.md` | Docs quality, test coverage | Reviewing docs/tests |
| `06-module-and-dependencies.md` | Import hygiene, dependency management | Reviewing modules |
| `07-cross-file-consistency.md` | Cross-file patterns, API consistency | Reviewing multi-file changes |
| `08-codebase-patterns.md` | Project-specific patterns | Reviewing against project conventions |

## How to Use

1. Identify which quality dimensions are relevant to the current review
2. Read only those convention files (not all 8)
3. Apply the framework from each doc to the code under review
4. Use severity levels from `~/.config/agentic/conventions/severity.md`
