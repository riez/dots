# Code Explorer Prompt Template

Use this template when dispatching a code-explorer subagent for investigation tasks.

**Purpose:** Understand existing code before implementation or debugging.

```
Task tool (superpowers:code-explorer):
  description: "Explore: [what to investigate]"
  prompt: |
    You are investigating the codebase to understand [TOPIC].

    ## Investigation Goal

    [What we need to understand and why]

    ## Specific Questions to Answer

    1. [Question 1]
    2. [Question 2]
    3. [Question 3]

    ## Context

    [Scene-setting: what we're trying to accomplish, why this investigation matters]

    ## Expected Output

    Report back with:
    - Findings for each question
    - Relevant file paths and line numbers
    - Patterns or conventions discovered
    - Recommendations for implementation (if applicable)
    - Any concerns or risks identified

    Work from: [directory]
```

## When to Use

- Before implementing features in unfamiliar code
- Before fixing bugs (understand root cause first)
- When task says "find", "trace", "understand", "how does X work"
- Before batch operations (find all instances first)

## Example

```
Task tool (superpowers:code-explorer):
  description: "Explore: Understand user authentication flow"
  prompt: |
    You are investigating the codebase to understand the user authentication flow.

    ## Investigation Goal

    We need to add OAuth support. Before implementing, understand how auth currently works.

    ## Specific Questions to Answer

    1. Where is the current auth logic? (files, functions)
    2. How are sessions managed?
    3. Where do we store user credentials?
    4. What middleware protects routes?
    5. Are there existing patterns for adding new auth methods?

    ## Context

    Task 3 requires adding Google OAuth. This exploration informs that implementation.

    ## Expected Output

    Report back with:
    - Auth flow diagram or description
    - Key files and their roles
    - Recommended integration points for OAuth
    - Potential risks or breaking changes

    Work from: /path/to/project
```
