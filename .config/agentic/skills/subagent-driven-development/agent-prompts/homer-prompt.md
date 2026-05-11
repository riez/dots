# Homer (Batch Processing) Prompt Template

Use this template when dispatching homer for batch/bulk operations.

**Purpose:** High-throughput parallel processing across many files.

```
Task tool (superpowers:homer):
  description: "Batch: [operation across files]"
  prompt: |
    You are performing a batch operation across multiple files.

    ## Batch Operation

    [What change to apply to all matching files]

    ## Target Files

    Pattern: [glob pattern or file list]
    Estimated count: [number of files]

    ## Transformation

    For each file:
    1. [Step 1]
    2. [Step 2]
    3. [Verification step]

    ## Context

    [Why this batch operation is needed, what triggered it]

    ## Constraints

    - [ ] Preserve existing functionality
    - [ ] Maintain type safety
    - [ ] Keep tests passing
    - [ ] Follow existing patterns

    ## Expected Output

    Report:
    - Files processed (count)
    - Files modified (count)
    - Files skipped with reasons
    - Any errors encountered
    - Test results after changes

    Work from: [directory]
```

## When to Use

- Renaming across entire codebase
- API migration (old → new)
- Refactoring patterns everywhere
- Updating imports in many files
- Changing component props globally

## Example

```
Task tool (superpowers:homer):
  description: "Batch: Update all Button components to new API"
  prompt: |
    You are updating all Button components to use the new API.

    ## Batch Operation

    Change: `<Button variant="primary">` → `<Button intent="primary">`
    Change: `<Button variant="secondary">` → `<Button intent="secondary">`
    Change: `<Button variant="danger">` → `<Button intent="destructive">`

    ## Target Files

    Pattern: src/**/*.tsx
    Estimated count: ~50 files

    ## Transformation

    For each file:
    1. Find all Button imports and usages
    2. Update variant prop to intent
    3. Map old values to new values
    4. Verify TypeScript compiles

    ## Context

    We upgraded our UI library. Button API changed from variant to intent.
    This is Task 4 of the UI upgrade plan.

    ## Constraints

    - [ ] Don't change Button components that use custom variants
    - [ ] Keep all existing tests passing
    - [ ] Maintain visual appearance

    ## Expected Output

    Report:
    - Total Button usages found
    - Files modified
    - Any edge cases skipped
    - TypeScript compilation result
    - Test results

    Work from: /path/to/project
```
