---
name: agent-orchestrator
description: "Intelligent agent selection for task dispatch. Use BEFORE spawning any subagent to select optimal agent type."
---

# Intelligent Agent Orchestrator

**MANDATORY:** Before dispatching ANY subagent, use this decision framework to select the optimal agent.

## Agent Selection Matrix

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    AGENT SELECTION DECISION TREE                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ANALYZE THE TASK:                                                       │
│                                                                          │
│  1. Is this a NEW feature requiring understanding first?                 │
│     └── YES → L.I.S.A. (Research-first, quality gates)                  │
│                                                                          │
│  2. Are you STUCK on the same error repeatedly?                         │
│     └── YES → B.A.R.T. (Creative pivots, branching strategies)          │
│                                                                          │
│  3. Does it involve SAFETY, MERGING, or INTEGRATION?                    │
│     └── YES → M.A.R.G.E. (Guardian, reconciler)                         │
│                                                                          │
│  4. Is it a BATCH operation across many files?                          │
│     └── YES → H.O.M.E.R. (Parallel processing, scale)                   │
│                                                                          │
│  5. Is it a SIMPLE task list needing persistence?                       │
│     └── YES → R.A.L.P.H. (Autonomous loop until done)                   │
│                                                                          │
│  6. Is it CODE EXPLORATION only (no changes)?                           │
│     └── YES → code-explorer (Read-only investigation)                   │
│                                                                          │
│  7. Is it IMPLEMENTATION with clear spec?                               │
│     └── YES → code-implementer (TDD-focused execution)                  │
│                                                                          │
│  DEFAULT: Use code-implementer for general tasks                        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Quick Reference

| Signal in Task | Agent | Why |
|----------------|-------|-----|
| "understand", "research", "analyze first" | **lisa** | Research before action |
| "stuck", "same error", "blocked", "pivot" | **bart** | Creative alternatives |
| "merge", "integrate", "safety", "security" | **marge** | Guardian role |
| "all files", "batch", "refactor entire", "scale" | **homer** | Parallel processing |
| "complete all", "autonomous", "PRD", "keep going" | **ralph** | Persistent loop |
| "explore", "how does", "find", "trace" | **code-explorer** | Read-only investigation |
| "implement", "build", "create", "add feature" | **code-implementer** | Standard implementation |

## Agent Capabilities Summary

### L.I.S.A. (Research-First)
- **Phases:** Research → Plan → Execute → Verify → Document
- **Enforces:** Quality gates (lint, types, tests), ethical constraints
- **Best for:** New features, complex changes needing understanding
- **Completion:** `VERIFIED_COMPLETE`

### B.A.R.T. (Creative Pivot)
- **Phases:** Conventional (5) → Creative (5) → Hail Mary (10)
- **Tracks:** Failed approaches, error signatures
- **Best for:** Debugging stuck issues, finding alternatives
- **Completion:** `COMPLETE`

### M.A.R.G.E. (Safety Guardian)
- **Hook:** PreToolUse (blocks before execution)
- **Blocks:** `rm -rf`, `git push --force`, `DROP DATABASE`
- **Best for:** Merges, deployments, security-sensitive work
- **Role:** Safety layer, not task completion

### H.O.M.E.R. (Parallel Scale)
- **Traits:** GREEDY, LAZY, NUCLEAR, UNSTOPPABLE
- **Features:** Parallel workers, reuses existing solutions, persists through setbacks
- **Best for:** Massive refactors, batch operations, large codebases
- **Completion:** `HOMER_COMPLETE`

### R.A.L.P.H. (Autonomous Loop)
- **Input:** prd.json with user stories
- **Process:** Pick story → Implement → Test → Commit → Update → Repeat
- **Best for:** PRD-driven development, task lists
- **Completion:** `<promise>COMPLETE</promise>`

## Dispatch Template

When dispatching, use this SLICE-compliant template:

```markdown
# Task: [Clear task name]

## Agent Selection Rationale
- **Selected Agent:** [agent name]
- **Why:** [reason based on decision tree]

## Context (S)
- **Project:** [path]
- **Current State:** [what exists]
- **Relevant Files:** [list]

## Scope (L + I)
- **Your Domain:** [what to work on]
- **Tools Available:** [Read/Write/Execute]

## Task Specification (C)
### Goal
[One clear sentence]

### Requirements
1. [Requirement 1]
2. [Requirement 2]

### Acceptance Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]

## Expected Output (E)
- Use SLICE-compliant output format
- Include completion promise for the selected agent
```

## Combining Agents

For complex workflows, chain agents:

1. **Exploration + Implementation:**
   ```
   code-explorer → understand the codebase
   lisa → implement with research-first approach
   ```

2. **Stuck + Fix:**
   ```
   lisa/code-implementer → initial attempt
   bart → when stuck on same error
   ```

3. **Implementation + Safety:**
   ```
   lisa/homer → implement changes
   marge → safety review before merge
   ```

4. **Batch + Quality:**
   ```
   homer → batch refactor
   lisa → quality verification pass
   ```

## Auto-Detection Signals

The orchestrator should detect these patterns and suggest agents:

| Pattern Detected | Suggested Agent |
|------------------|-----------------|
| Multiple consecutive failures with same error | bart |
| Task mentions "100+ files" or "entire codebase" | homer |
| Task mentions "understand" or "how does X work" | lisa or code-explorer |
| Task involves merge, deploy, or security | marge |
| Task has numbered list of items to complete | ralph |
| Unknown/general implementation task | code-implementer |

## Integration with SLICE + TDD-Guard

All agents:
1. Receive SLICE methodology context via SessionStart hook
2. Are subject to tdd-guard enforcement when installed
3. Must produce SLICE-compliant output
4. Follow TDD practices (test first where applicable)
