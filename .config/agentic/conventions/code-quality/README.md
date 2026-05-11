# Code Quality Guidelines

A comprehensive framework for detecting code smells through LLM-agent evaluation, organized into eight documents addressing distinct cognitive modes.

## Structure Overview

The framework spans eight evaluation documents, each targeting a specific question:

| Document | Core Question |
|----------|---------------|
| 01-naming-and-types.md | Do names and types express intent? |
| 02-structure-and-composition.md | Is this well-structured? |
| 03-patterns-and-idioms.md | Is this idiomatic? |
| 04-repetition-and-consistency.md | Is this DRY and consistent? |
| 05-documentation-and-tests.md | Is this documented and tested? |
| 06-module-and-dependencies.md | Are boundaries clean? |
| 07-cross-file-consistency.md | Is this consistent across files? |
| 08-codebase-patterns.md | What patterns are emerging? |

## Applicability Matrix

Each document applies differently depending on the evaluation phase:

| Phase | Applicable Documents |
|-------|---------------------|
| Design Review | 01, 02, 06, 07 |
| Diff Review | 01-05 |
| Codebase Review | All (01-08) |
| Refactor Design | 01, 02, 06, 07 |
| Refactor Code | All (01-08) |

## Format Methodology

Each document contains:

1. **Primer**: Establishes cognitive mode through 2-3 grounding paragraphs
2. **Numbered Categories**: Each containing:
   - Principle
   - Detection questions
   - Grep hints
   - Violation patterns with severity
   - Exceptions
   - Thresholds

## Severity Levels

| Level | Meaning |
|-------|---------|
| [high] | Blocks merge / requires immediate fix |
| [medium] | Should fix before merge if time permits |
| [low] | Note for future improvement |

## Usage

When reviewing code:
1. Select documents based on review phase (see matrix above)
2. For each document, answer its core question
3. Use grep hints to find potential violations
4. Apply thresholds to determine if finding is reportable
5. Check exceptions before reporting
