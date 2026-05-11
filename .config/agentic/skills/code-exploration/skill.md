---
name: code-exploration
description: "MANDATORY before any coding task. Dispatches code-explorer agent to understand codebase before implementation. Use for: new feature, bug fix, refactor, any code change, understand code, explore codebase"
---

# Code Exploration Protocol

**This skill MUST be invoked before any coding task.** The orchestrator (you) must understand the codebase through the code-explorer agent before writing any code.

## Why This Exists

- Implementation starts with understanding: explore first
- Chunk-by-chunk exploration prevents context overload
- Fresh exploration ensures up-to-date understanding
- Separation of concerns: exploration vs implementation

## The Flow

```
User Request → Orchestrator Analyzes → Identifies Knowledge Gaps →
Code Explorer Fills Gaps → Orchestrator Implements
```

## Step 1: Analyze the Request

When user asks for any code change, first identify:
1. What part of the codebase is involved?
2. What do I need to understand before implementing?
3. What are my specific questions?

Example analysis:
```
User wants: "Add dark mode toggle to settings"

I need to understand:
- Where is the settings page? → Question 1
- How is theming currently handled? → Question 2
- What state management is used? → Question 3
```

## Step 2: Dispatch Code Explorer (One Question at a Time)

Use the Task tool with `code-explorer` droid. Ask ONE specific question per dispatch.

**Good questions:**
- "How does the authentication flow work from login to session creation?"
- "Where are the API routes defined and what middleware do they use?"
- "What components consume the ThemeContext and how?"

**Bad questions:**
- "Tell me about the codebase" (too broad)
- "How should I implement X?" (that's your job)
- "What's the best approach?" (explorer doesn't decide)

## Step 3: Receive and Validate

When code-explorer returns:
1. Read the findings
2. Check if you have enough context
3. If gaps remain → dispatch another specific question
4. If clear → proceed to implementation

## Step 4: Iterate as Needed

During implementation, if you hit unknowns:
- STOP implementing
- Dispatch code-explorer with the new question
- Continue only after understanding

## Dispatch Template

```
Task tool call:
- subagent_type: "code-explorer"
- description: "Explore [topic]"
- prompt: |
    Question: [Your specific question]

    Context: I'm working on [brief task description].

    I specifically need to know:
    - [Specific aspect 1]
    - [Specific aspect 2]

    Please explore and report back with file references.
```

## Documentation Lookup

If the question involves external docs, include in prompt:
```
This involves [library/framework]. Please also check:
- Official documentation (use WebSearch with 2025)
- Any MCP tools like context7 or ref if available
```

## Anti-Patterns

**Skip:**
- Exploration-free guessing
- Ask vague questions
- Ask implementation questions to explorer
- Ignore gaps in explorer's response
- Explore everything at once

**DO:**
- Ask specific, scoped questions
- Iterate chunk by chunk
- Validate understanding before coding
- Re-explore when hitting unknowns during implementation

## Example Session

```
User: "Add user avatar upload to profile page"

Orchestrator thinks: I need to understand...
1. Where is the profile page?
2. How are images currently handled?
3. What's the file upload mechanism?

[Dispatch #1]
Question: "Where is the profile page component and what props/state does it manage?"

[Explorer returns with findings]

[Dispatch #2]
Question: "How are images stored and served in this application? Check for any image processing utilities."

[Explorer returns]

[Dispatch #3]
Question: "Is there existing file upload functionality? If so, how does it work?"

[Explorer returns]

Orchestrator: Now I understand enough to implement.
```

## Refresh Protocol

Even for familiar codebases, always do at least ONE exploration dispatch to:
- Verify assumptions are still valid
- Catch recent changes
- Refresh context in your working memory
