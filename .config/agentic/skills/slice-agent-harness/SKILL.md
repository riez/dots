---
name: slice-agent-harness
description: "MANDATORY harness for all agent orchestration. Enforces SLICE methodology - Specify context, Limit tools, Isolate agents, Create task specs, Evaluate quality. Use BEFORE dispatching ANY subagent or starting ANY multi-step task."
---

# SLICE Agent Harness

**This skill is MANDATORY for ALL agent orchestration.** Every subagent dispatch MUST pass through SLICE validation.

## What is SLICE?

SLICE is a methodology for effective agent orchestration:

| Letter | Principle | Purpose |
|--------|-----------|---------|
| **S** | Specify Context | Give agent exactly the context it needs - no more, no less |
| **L** | Limit Tools | Restrict agent to only tools required for the task |
| **I** | Isolate Agents | Each agent works in isolation, no shared mutable state |
| **C** | Create Task Specs | Write complete, unambiguous task specifications |
| **E** | Evaluate Quality | Define success criteria and required output format |

---

## SLICE Checklist (MANDATORY)

Before dispatching ANY subagent, verify ALL of these:

### S - Specify Context
- [ ] What files/code does the agent need to know about?
- [ ] What is the current state of the system?
- [ ] What decisions have already been made?
- [ ] What constraints exist?
- [ ] **For frameworks/libraries:** What components are available? (MUST research first)
- [ ] **Anti-pattern:** "Just look at the codebase" (too vague)
- [ ] **Anti-pattern:** "Use SkeletonUI" without listing available components
- [ ] **Good:** Provide specific file paths, relevant code snippets, architectural decisions
- [ ] **Good:** For frameworks, include: version, available components list, components to use

### L - Limit Tools
- [ ] What tools does this task actually require?
- [ ] Are there tools that could cause harm if misused?
- [ ] Should the agent be read-only or read-write?
- [ ] **Anti-pattern:** Giving all tools to every agent
- [ ] **Good:** Explorer agents get read-only, implementers get write access

### I - Isolate Agents
- [ ] Can this agent work without affecting other agents?
- [ ] Is there shared state that could cause conflicts?
- [ ] Will multiple agents edit the same files?
- [ ] **Anti-pattern:** Two agents editing same file simultaneously
- [ ] **Good:** Each agent owns specific files/domains

### C - Create Task Specs
- [ ] Is the task description unambiguous?
- [ ] Are acceptance criteria clear?
- [ ] Are edge cases mentioned?
- [ ] Is scope explicitly bounded?
- [ ] **Anti-pattern:** "Fix the tests"
- [ ] **Good:** "Fix tests in file X, root cause is Y, expected behavior is Z"

### E - Evaluate Quality
- [ ] What does success look like?
- [ ] What output format is required?
- [ ] How will the orchestrator verify completion?
- [ ] **Anti-pattern:** "Let me know when done"
- [ ] **Good:** Require structured output with specific sections

---

## Required Output Format for Subagents

**ALL subagents MUST return output in this format:**

```markdown
## Task Summary
[1-2 sentence summary of what was asked]

## Status
[COMPLETED | PARTIALLY_COMPLETED | BLOCKED | FAILED]

## What Was Done
- [Specific action 1]
- [Specific action 2]
- [...]

## Files Changed
- `path/to/file.ts` - [what changed]
- `path/to/other.ts` - [what changed]

## Verification
- [ ] Tests pass: [YES/NO] - [details]
- [ ] Lint passes: [YES/NO] - [details]
- [ ] Manual verification: [details]

## Output for Orchestrator
[Specific information the orchestrator requested]

## Blockers/Issues (if any)
- [Issue 1 and what's needed to resolve]

## Questions for Orchestrator (if any)
- [Question that needs answer before continuing]
```

---

## Subagent Dispatch Template

Use this template when dispatching ANY subagent:

```markdown
# Task: [Clear, specific task name]

## Context (S)
- **Project:** [What project/repo]
- **Current State:** [What's already done, what's the situation]
- **Relevant Files:**
  - `path/to/file.ts` - [why relevant]
- **Decisions Already Made:** [What's been decided]
- **Constraints:** [What NOT to do]

## Scope (L + I)
- **Your Domain:** [What files/areas you own]
- **Out of Scope:** [What's off-limits]
- **Tools Available:** [Read/Write/Execute/etc.]

## Task Specification (C)
### Goal
[One clear sentence describing the goal]

### Requirements
1. [Specific requirement 1]
2. [Specific requirement 2]

### Acceptance Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]

### Out of Scope
- [What NOT to do]

## Expected Output (E)
### Required Sections
1. **Summary:** What you did
2. **Files Changed:** List with descriptions
3. **Verification:** Tests, lint, manual checks
4. **[Custom]:** [Specific data orchestrator needs]

### Success Criteria
- [How orchestrator will verify completion]
```

---

## Orchestrator Responsibilities

The orchestrator (you, the main agent) MUST:

1. **Before Dispatching:**
   - Run SLICE checklist mentally
   - Prepare complete context
   - Define clear output requirements
   - Verify isolation (no conflicts with other agents)

2. **When Receiving Output:**
   - Verify output follows required format
   - Check status (COMPLETED vs other)
   - Extract information needed for next steps
   - Handle blockers/questions immediately

3. **On Failure:**
   - Vary the dispatch spec based on what was missing or low-quality
   - Analyze why it failed
   - Provide additional context if needed
   - Consider breaking into smaller tasks

---

## MANDATORY: Framework/Library Research

**When a task involves ANY external library or framework, you MUST:**

### Before Dispatching Implementation

1. **Identify the library** - What framework/library is involved?
2. **Find the version** - Check package.json, Cargo.toml, requirements.txt, etc.
3. **Research available features** - Use WebSearch or ref tools to find:
   - Official component list
   - Available utilities and helpers
   - Best practices and patterns
4. **Audit current usage** - What's already used in the codebase?
5. **Document the gap** - What's available but NOT being used?

### Required Research Output Format

```markdown
## Framework Research: [Name] v[version]

### Source
- Docs URL: [official docs link]
- Research method: [WebSearch/ref/context7]

### Available Components
| Component | Purpose | Currently Used? |
|-----------|---------|-----------------|
| AppShell | Layout wrapper | No |
| Modal | Dialog overlay | No |
| Toast | Notifications | No |
| Table | Data tables | No |
| ... | ... | ... |

### Available Utilities
- utility1 - [purpose]
- utility2 - [purpose]

### Currently Used in Codebase
- ComponentA (in file X)
- utilityB (in file Y)

### Recommended for This Task
- Use [Component] for [purpose]
- Use [Utility] for [purpose]

### Files to Update
- `path/file.svelte` - Replace custom X with [Component]
```

Dispatch implementation once this research is complete.

---

## Common Anti-Patterns

### Bad: Vague Context
```
Task: Fix the authentication bug
```

### Good: Specific Context
```
Task: Fix authentication bug in src/auth/login.ts

Context:
- Users report 401 errors after token refresh
- Bug introduced in commit abc123
- Relevant files: src/auth/login.ts, src/auth/token.ts
- Current behavior: Token refresh returns 401
- Expected behavior: Token refresh returns new valid token
```

### Bad: No Output Requirements
```
Let me know what you find.
```

### Good: Structured Output
```
Return your findings in this format:
1. Root Cause: [one sentence]
2. Files Involved: [list]
3. Recommended Fix: [specific changes]
4. Risk Assessment: [low/medium/high + reasoning]
```

### Bad: Overlapping Scope
```
Agent 1: Fix all test failures
Agent 2: Refactor the test utilities
```

### Good: Isolated Scope
```
Agent 1: Fix tests in src/auth/*.test.ts (owns auth domain)
Agent 2: Fix tests in src/api/*.test.ts (owns api domain)
```

### Bad: Framework Task Without Research
```
Task: Use SkeletonUI for all components
[Dispatches implementation immediately]
Result: Agent only uses CSS classes, misses actual Svelte components
```

### Good: Framework Task With Research
```
Step 1: Research SkeletonUI v2.10.0
- Find: AppShell, Modal, Toast, Table, Paginator, etc.
- Find: Current usage in codebase
- Find: Files that need updating

Step 2: Dispatch with full context
Task: Use SkeletonUI components for all pages
Context:
- Version: 2.10.0
- Available components: [full list from research]
- Currently used: [list]
- Files to update: [specific list]
- Components to use: Modal for dialogs, Table for data, Toast for notifications
```

---

## Integration Points

**Skills that MUST use SLICE:**
- `dispatching-parallel-agents` - Each parallel agent needs SLICE
- `subagent-driven-development` - Each task dispatch needs SLICE
- `code-exploration` - Explorer agent dispatches need SLICE
- `executing-plans` - Plan step dispatches need SLICE

**Droids that MUST follow SLICE output format:**
- `code-explorer` - Must return structured findings
- `code-implementer` - Must return structured completion report
- `code-reviewer` - Must return structured review

---

## MANDATORY: Output Validation

**The orchestrator MUST validate ALL subagent outputs before proceeding.**

### Validation Checklist

When receiving output from a subagent, verify:

```
□ Status is COMPLETED (not BLOCKED/FAILED/PARTIALLY_COMPLETED)
□ ALL requested information items are present
□ No unanswered questions remain
□ No blockers that need resolution
□ Output format matches SLICE-compliant structure
```

### Information Completeness Check

**CRITICAL:** If you requested N pieces of information, you MUST receive N pieces back.

```
Orchestrator requests 5 items:
1. Project structure
2. Key dependencies
3. Entry points
4. Configuration files
5. Test setup

Subagent returns only 4 items (missing #5)
       ↓
   ┌─────────────────────────────────────────┐
   │ RE-DISPATCH SUBAGENT, THEN PROCEED.    │
   │ "You missed item #5 (test setup).       │
   │ Please provide this information."       │
   └─────────────────────────────────────────┘
```

### Re-dispatch Template

When subagent output is incomplete:

```markdown
Your previous response was incomplete.

Missing information:
- [Item X]: [What was requested but not provided]
- [Item Y]: [What was requested but not provided]

Please provide ONLY the missing information above.
Use the same SLICE-compliant output format.
```

### Validation Flow

```
Receive subagent output
       ↓
Check Status field
       ↓
   Status = COMPLETED?
   ├── NO → Check Blockers/Questions, resolve them, re-dispatch
   └── YES ↓
       ↓
Count information items received vs requested
       ↓
   All items present?
   ├── NO → Re-dispatch for missing items ONLY
   └── YES ↓
       ↓
Check for quality (not just presence)
       ↓
   Information is actionable?
   ├── NO → Re-dispatch with clarification request
   └── YES ↓
       ↓
PROCEED with task
```

### Anti-Patterns

| Wrong | Right |
|-------|-------|
| Accept incomplete output and guess the rest | Re-dispatch for missing items |
| Proceed when Status is BLOCKED | Resolve blockers first, then re-dispatch |
| Ignore "Questions for Orchestrator" section | Answer questions, then re-dispatch |
| Accept vague answers | Request specific, actionable information |
| Dispatch new subagent for missing info | Re-dispatch SAME subagent to complete its task |

### Maximum Re-dispatch Attempts

- **Limit:** 3 re-dispatch attempts per subagent task
- **After 3 failures:** Report to user that subagent could not complete task
- **Include:** What was received vs what was missing

---

## Quick Reference

```
SLICE = Specify, Limit, Isolate, Create, Evaluate

Before dispatch:
✓ Context complete and specific?
✓ Tools limited to task needs?
✓ Agent isolated from others?
✓ Task spec unambiguous?
✓ Output format defined?
✓ Required information items listed explicitly?

After receiving output:
✓ Status is COMPLETED?
✓ ALL required information items present? (count them!)
✓ Verification checks passed?
✓ No blockers/questions pending?
✓ Information is actionable quality?

If any check fails, re-dispatch before proceeding
```

---

## MANDATORY: Detailed Todo Format

**Every todo item MUST include these components:**

```
N. [status] TASK: <clear task description>
   AGENT: <agent> | METHOD: <approach> | OUTPUT: <expected deliverable>
```

### Component Definitions

| Component | Description | Example |
|-----------|-------------|---------|
| **TASK** | Clear, specific description of what to do | "Implement OAuth2 login flow" |
| **AGENT** | Which agent will handle this | lisa, bart, homer, marge, ralph, code-explorer, code-implementer |
| **METHOD** | How the agent will approach it | "Research → TDD → Document" |
| **OUTPUT** | Concrete expected deliverable | "Auth module with tests passing, docs updated" |

### Agent Selection Guide for Todos

| Task Characteristic | Agent | Method | Typical Output |
|---------------------|-------|--------|----------------|
| New feature, needs understanding | **lisa** | Research → Plan → TDD → Document | Tested code + docs |
| Stuck, same error repeatedly | **bart** | Conventional → Creative → Hail Mary | Working solution |
| Batch operation, many files | **homer** | Parallel GREEDY/LAZY processing | All files processed |
| Safety-critical, deployment | **marge** | Security checklist, guard execution | Approval or blockers |
| PRD/task list, autonomous | **ralph** | Loop until all stories pass | All PRD items complete |
| Investigation only, no changes | **code-explorer** | Read-only exploration | Structured findings |
| Standard implementation | **code-implementer** | TDD-focused execution | Tested implementation |

### Good Todo Examples

**Format:** `N. [status] TASK: <desc> | AGENT: <agent> | METHOD: <approach> | OUTPUT: <deliverable>`

```
1. [in_progress] TASK: Implement OAuth2 auth | AGENT: lisa | METHOD: Research→TDD→Document | OUTPUT: src/auth/ with 90%+ coverage
2. [pending] TASK: Fix undefined error in UserProfile | AGENT: bart | METHOD: Conventional→Creative pivot | OUTPUT: Component working
3. [pending] TASK: Convert 47 components to TS strict | AGENT: homer | METHOD: Parallel batch + LAZY | OUTPUT: tsc --strict passes
4. [pending] TASK: Security review for v2.0 | AGENT: marge | METHOD: OWASP + dependency audit | OUTPUT: Security report
5. [pending] TASK: Complete 8 PRD stories | AGENT: ralph | METHOD: Autonomous loop | OUTPUT: All stories pass
6. [pending] TASK: Understand payment flow | AGENT: code-explorer | METHOD: Trace API→services | OUTPUT: Flow diagram + files
```

### Todo Examples to Improve

```
1. [pending] Fix auth                    ← Missing: AGENT, METHOD, OUTPUT
2. [pending] Update components           ← Too vague, no agent assignment
3. [pending] Deploy                      ← No method, no expected output
4. [pending] TASK: Do stuff | AGENT: ??? ← Agent not selected based on task type
```

### Todo Validation Checklist

Before creating a todo, verify:
- [ ] TASK is specific and actionable (not vague)
- [ ] AGENT is explicitly assigned based on task type
- [ ] METHOD describes the approach the agent will use
- [ ] OUTPUT is a concrete, verifiable deliverable
- [ ] Task can be completed in reasonable scope (split if too large)
