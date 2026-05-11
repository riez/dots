---
name: using-superpowers
description: Use when starting any conversation - establishes how to find and use skills, requiring Skill tool invocation before ANY response including clarifying questions
---

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing, invoke the skill and follow it.

When a skill applies to your task, treat it as required and use it.

This is a reliability mechanism: it keeps behavior consistent across tasks and reduces missed steps.
</EXTREMELY-IMPORTANT>

---

## MANDATORY: Subagent Routing

**YOU ARE AN ORCHESTRATOR.** Before answering questions about code/projects, dispatch the appropriate subagent and base your response on their findings.

### Routing Table

| User Intent Pattern | Dispatch To | Skill Required |
|---------------------|-------------|----------------|
| "what is this project/structure/code" | `code-explorer` | `code-exploration` |
| "how does X work" | `code-explorer` | `code-exploration` |
| "where is X implemented" | `code-explorer` | `code-exploration` |
| "explain this codebase" | `code-explorer` | `code-exploration` |
| "understand the flow of X" | `code-explorer` | `code-exploration` |
| UX/user experience questions | `ux-researcher` | `ux-research` |
| "interview guide/questions" | `ux-researcher` | `ux-research` |
| "transcript/synthesis/insights" | `ux-researcher` | `ux-research` |
| "implement/build/create feature" | `code-implementer` | `code-exploration` first, then implement |
| "fix bug/issue" | `code-explorer` first | `systematic-debugging` |
| "review this code" | `code-reviewer` | `requesting-code-review` |

### Routing Flow

```
User prompt arrives
       ↓
Match against routing table
       ↓
   ┌───────────────────────────────────────┐
   │ ALWAYS invoke `slice-agent-harness`   │
   │ skill BEFORE dispatching ANY subagent │
   └───────────────────────────────────────┘
       ↓
List EXACTLY what information you need (e.g., 5 items)
       ↓
Dispatch appropriate subagent via Task tool
       ↓
Receive SLICE-compliant output
       ↓
   ┌───────────────────────────────────────┐
   │ VALIDATE: Did subagent return ALL     │
   │ requested items? Count them!          │
   │                                       │
   │ Requested: 5 items                    │
   │ Received:  4 items                    │
   │ → RE-DISPATCH for missing item #5    │
   └───────────────────────────────────────┘
       ↓
All items present & actionable?
       ↓
   YES → Summarize findings to user
   NO  → Re-dispatch (max 3 attempts)
```

### Output Validation (MANDATORY)

**Before proceeding, the orchestrator MUST verify:**

1. **Status Check:** Is status `COMPLETED`? (not BLOCKED/FAILED)
2. **Completeness Check:** Count items requested vs received
3. **Quality Check:** Is information actionable, not vague?
4. **Blockers Check:** Any unresolved blockers or questions?

If any check fails, re-dispatch the subagent before proceeding.

```
Example:
- You requested: project structure, dependencies, entry points, config, tests
- Subagent returned: project structure, dependencies, entry points, config
- Missing: tests
- Action: Re-dispatch asking ONLY for the missing "tests" information
```

### Preferred Patterns

| Wrong | Right |
|-------|-------|
| Answer "what is this project" by running `ls` yourself | Dispatch `code-explorer` to investigate and report |
| Answer UX questions from your own knowledge | Dispatch `ux-researcher` to provide structured analysis |
| Start implementing without understanding | Dispatch `code-explorer` first, then `code-implementer` |
| Review code yourself | Dispatch `code-reviewer` for structured review |
| Accept incomplete output (4/5 items) and proceed | Re-dispatch for missing items before proceeding |
| Guess missing information | Re-dispatch subagent to get the actual information |
| Proceed when Status is BLOCKED/FAILED | Resolve blockers, then re-dispatch |

### Example Routing

**User:** "what is this project structure?"
```
1. Recognize: code understanding question → route to code-explorer
2. Invoke: slice-agent-harness skill
3. Dispatch: Task(subagent_type="code-explorer", prompt="Explore project structure...")
4. Receive: SLICE-compliant output from code-explorer
5. Summarize: Present findings to user
```

**User:** "what do you think about the UX, what can we improve?"
```
1. Recognize: UX question → route to ux-researcher AND code-explorer
2. Invoke: slice-agent-harness skill
3. Dispatch: code-explorer first (understand current UX implementation)
4. Dispatch: ux-researcher (analyze and provide recommendations)
5. Synthesize: Combine both outputs for user
```

---

## How to Access Skills

**In Claude Code:** Use the `Skill` tool. When you invoke a skill, its content is loaded and presented to you—follow it directly. Use `Read` for project files rather than skill definitions.

**In other environments:** Check your platform's documentation for how skills are loaded.

# Using Skills

## The Rule

**Check for skills BEFORE ANY RESPONSE.** This includes clarifying questions. Even 1% chance means invoke the Skill tool first.

```dot
digraph skill_flow {
    "User message received" [shape=doublecircle];
    "Might any skill apply?" [shape=diamond];
    "Invoke Skill tool" [shape=box];
    "Announce: 'Using [skill] to [purpose]'" [shape=box];
    "Has checklist?" [shape=diamond];
    "Create TodoWrite todo per item" [shape=box];
    "Follow skill exactly" [shape=box];
    "Respond (including clarifications)" [shape=doublecircle];

    "User message received" -> "Might any skill apply?";
    "Might any skill apply?" -> "Invoke Skill tool" [label="yes, even 1%"];
    "Might any skill apply?" -> "Respond (including clarifications)" [label="definitely not"];
    "Invoke Skill tool" -> "Announce: 'Using [skill] to [purpose]'";
    "Announce: 'Using [skill] to [purpose]'" -> "Has checklist?";
    "Has checklist?" -> "Create TodoWrite todo per item" [label="yes"];
    "Has checklist?" -> "Follow skill exactly" [label="no"];
    "Create TodoWrite todo per item" -> "Follow skill exactly";
}
```

## Red Flags

These thoughts mean STOP—you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "I can check git/files quickly" | Files lack conversation context. Check for skills. |
| "Let me gather information first" | Skills tell you HOW to gather information. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "I remember this skill" | Skills evolve. Read current version. |
| "This doesn't count as a task" | Action = task. Check for skills. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |

## Skill Priority

When multiple skills could apply, use this order:

1. **Agent orchestration** (slice-agent-harness) - MANDATORY before dispatching ANY subagent
2. **Process skills** (brainstorming, debugging) - these determine HOW to approach the task
3. **Implementation skills** (frontend-design, mcp-builder) - these guide execution

"Dispatch agent for X" → slice-agent-harness ALWAYS first.
"Let's build X" → brainstorming first, then implementation skills.
"Fix this bug" → debugging first, then domain-specific skills.

## Skill Types

**Rigid** (TDD, debugging): Follow exactly and keep the discipline intact.

**Flexible** (patterns): Adapt principles to context.

The skill itself tells you which.

## User Instructions

Instructions say WHAT, not HOW. "Add X" or "Fix Y" doesn't mean skip workflows.
