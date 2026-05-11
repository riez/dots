---
name: prompt-crafting
description: Model-specific prompt refinement guidance for GPT, Claude, and Gemini based on Factory's power-user prompt crafting guide. Use when preparing complex prompts, translating rough requests into higher-signal instructions, or adapting the same task to different model families.
---

# Prompt Crafting

Use this skill when a prompt is underspecified, when outcome quality depends heavily on prompt shape, or when the target model family matters.

Source:
- Factory documentation: `https://docs.factory.ai/guides/power-user/prompt-crafting`

## When To Use

Apply this skill when:
- the user wants help writing or improving a prompt
- the task is complex, multi-step, or easy to misinterpret
- the model family is known and prompt structure should be adapted to it
- the same request needs to work well across CLI agents using different providers

Do not use this skill for simple direct requests that are already unambiguous.

## Universal Rules

Every refined prompt should make these explicit:
- the desired outcome
- the relevant context
- constraints and non-goals
- acceptance criteria or definition of done
- expected output shape

Prefer concrete prompts over abstract ones.

Weak:
- `Fix the auth bug`

Stronger:
- `Fix the login timeout bug where users are logged out after five minutes of inactivity. Preserve the current public API, keep test coverage intact, and ensure sessions persist for 24 hours.`

## Refinement Workflow

### 1. Diagnose the draft

Check whether the draft prompt includes:
- a clear goal
- sufficient context
- explicit constraints
- measurable success criteria
- output format instructions

If any are missing, add them.

### 2. Choose the model-specific shape

Use the target model family to decide how to structure the prompt:
- Claude: XML-like sections and explicit structure
- GPT/Codex: role framing, numbered procedures, explicit output format
- Gemini: more complete context and explicit reasoning level

### 3. Tighten the prompt

Refine until the prompt:
- names the exact task
- points to relevant files, systems, or modules
- specifies how the answer should be returned
- avoids vague language like `improve`, `optimize`, or `make better` without metrics

### 4. Return the result

When asked to refine a prompt:
- provide the improved prompt
- briefly note what changed and why only if useful
- preserve the user's intent, but remove ambiguity

## Model-Specific Guidance

## Claude

Claude responds best to structured prompts with clearly separated sections.

Use:
- XML-style tags such as `<context>`, `<task>`, `<requirements>`, `<constraints>`, `<examples>`
- context before instructions
- dedicated example sections for input/output patterns
- explicit reasoning instructions for hard decisions

Recommended order:
1. `<context>`
2. `<task>`
3. `<requirements>`
4. `<constraints>`
5. `<examples>`

Claude prompt template:

```text
<context>
[System background, codebase state, relevant modules, constraints from the environment]
</context>

<task>
[The exact action to take]
</task>

<requirements>
- [Must-have behavior]
- [Tests, docs, validation, edge cases]
</requirements>

<constraints>
- [APIs that cannot change]
- [Compatibility or performance limits]
</constraints>

<examples>
Input: ...
Output: ...
</examples>
```

For complex work, add:
- `Think through the approach before implementing.`
- `Consider these edge cases: ...`
- `Explain the reasoning for key decisions where tradeoffs exist.`

## GPT / Codex

GPT-family models respond best to explicit role framing and ordered procedures.

Use:
- a strong role statement at the top
- numbered steps for any procedural task
- exact output-format instructions
- explicit reasoning request for hard problems

Recommended order:
1. role
2. context
3. task
4. numbered steps
5. output format
6. examples if needed

GPT prompt template:

```text
You are a [specific role] working on [specific system or context].

Context:
[Relevant background, files, systems, risks]

Task:
[The exact action to take]

Steps:
1. ...
2. ...
3. ...

Output format:
- Return as [markdown / JSON / patch / checklist]
- Include [specific sections]

Constraints:
- ...
- ...
```

For harder reasoning tasks, add:
- `Think through this step by step before deciding.`

## Gemini

Gemini handles larger context well and benefits from explicit reasoning-level guidance.

Use:
- fuller background context when it materially helps
- structured sections
- explicit instruction for low vs high reasoning

Prefer Gemini for:
- architecture analysis
- research-heavy tasks
- large-context synthesis

Gemini prompt template:

```text
Context:
[Include broader project or system context when relevant]

Task:
[The exact action]

Reasoning level:
[Low or High, depending on the task]

Constraints:
- ...

Output:
[Desired format]
```

## Quick Selection Guide

Choose structure based on target model:
- Claude: strongest for XML-style structured prompts and explicit reasoning scaffolds
- GPT/Codex: strongest for role-based, procedural, output-specified prompts
- Gemini: strongest when more background context helps and long-context synthesis matters

## Prompt Review Checklist

Before finalizing a refined prompt, verify:
- [ ] The task is specific
- [ ] The model has enough context to act correctly
- [ ] Constraints are explicit
- [ ] Success criteria are measurable
- [ ] Output format is defined
- [ ] The prompt shape matches the target model family

## Response Pattern

When this skill is invoked, do one of the following:

1. If the user supplied a rough prompt:
   - return a refined prompt optimized for the target model

2. If the user supplied a task but not a prompt:
   - draft a prompt from scratch using the appropriate model template

3. If the task must work across model families:
   - provide separate Claude and GPT variants
   - provide a Gemini variant only when Gemini is in scope

Keep refined prompts concise, concrete, and executable.
