# Bart (Creative Pivot) Prompt Template

Use this template when dispatching bart for creative problem-solving when stuck.

**Purpose:** Find alternative approaches when the current approach is blocked.

```
Task tool (superpowers:bart):
  description: "Pivot: Find alternative for [stuck problem]"
  prompt: |
    We're stuck on [PROBLEM]. Need a creative alternative approach.

    ## What We Tried

    [List approaches that didn't work]

    ## Why It's Blocked

    [The specific issue preventing progress]

    ## Constraints

    - [Constraint 1]
    - [Constraint 2]
    - [Must still achieve: goal]

    ## Context

    [Background on the original task and why it matters]

    ## Your Job

    Think creatively:
    1. Why are the current approaches failing?
    2. What assumptions can we challenge?
    3. What alternative patterns exist?
    4. Is there a simpler way?

    Propose 2-3 alternative approaches with:
    - How it works
    - Pros and cons
    - Implementation complexity
    - Your recommendation

    Work from: [directory]
```

## When to Use

- Same error repeatedly despite fixes
- Blocked by external dependency
- Approach seems impossible
- Need fresh perspective
- Performance issue with no obvious solution

## Example

```
Task tool (superpowers:bart):
  description: "Pivot: Find alternative for flaky test issue"
  prompt: |
    We're stuck on flaky integration tests. Need a creative alternative.

    ## What We Tried

    1. Added explicit waits - still flaky
    2. Increased timeouts - still flaky
    3. Reset database between tests - still flaky
    4. Ran tests serially - still flaky (and slow)

    ## Why It's Blocked

    Tests randomly fail on CI but pass locally. Race condition suspected
    but can't identify the source despite extensive debugging.

    ## Constraints

    - Must run in CI pipeline
    - Can't remove the tests (critical paths)
    - Need reasonable execution time (<5 min)

    ## Context

    Task 7 requires these integration tests to pass before we can ship.
    Blocking the release.

    ## Your Job

    Think creatively:
    1. Why are these approaches failing?
    2. Could we test differently? (unit vs integration)
    3. Could we isolate the flaky parts?
    4. Is there a test infrastructure change that helps?

    Propose 2-3 alternatives with pros/cons.

    Work from: /path/to/project
```
