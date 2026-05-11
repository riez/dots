# Lisa (Research-First) Prompt Template

Use this template when dispatching lisa for research-heavy tasks.

**Purpose:** Research thoroughly before implementation. Quality gates ensure evidence-based work.

```
Task tool (superpowers:lisa):
  description: "Research: [topic to investigate]"
  prompt: |
    You are researching [TOPIC] before implementation begins.

    ## Research Goal

    [What we need to learn and why it matters for the implementation]

    ## Research Questions

    1. [Question about existing code/patterns]
    2. [Question about best practices/approaches]
    3. [Question about risks/tradeoffs]
    4. [Question about dependencies/integration]

    ## Context

    [Scene-setting: what implementation will follow, constraints, requirements]

    ## Quality Gates

    Your research must answer:
    - [ ] What patterns exist in the codebase?
    - [ ] What's the recommended approach?
    - [ ] What are the risks?
    - [ ] What's the implementation plan?

    ## Expected Output

    Provide:
    - Summary of findings
    - Recommended approach with rationale
    - Implementation plan (steps)
    - Risks and mitigations
    - Files that will need changes

    Work from: [directory]
```

## When to Use

- Tasks involving external APIs or libraries
- Tasks requiring architectural decisions
- When "best approach" is unclear
- Complex features needing investigation
- Integration with unfamiliar systems

## Example

```
Task tool (superpowers:lisa):
  description: "Research: Stripe payment integration patterns"
  prompt: |
    You are researching Stripe payment integration before implementation.

    ## Research Goal

    We need to add Stripe payments. Research the best approach for our codebase.

    ## Research Questions

    1. Do we have existing payment code or interfaces?
    2. What Stripe SDK patterns work best with our stack (Next.js + TypeScript)?
    3. How should we handle webhooks securely?
    4. What's the testing strategy for payments?

    ## Context

    This is for Task 2 in our e-commerce plan. We need checkout, subscriptions,
    and refund capabilities. Must work with existing User model.

    ## Quality Gates

    Your research must answer:
    - [ ] Existing payment patterns in codebase
    - [ ] Recommended Stripe SDK approach
    - [ ] Webhook handling strategy
    - [ ] Testing approach
    - [ ] Security considerations

    ## Expected Output

    Provide:
    - Summary of findings
    - Recommended architecture
    - Step-by-step implementation plan
    - Code structure recommendation
    - Test strategy

    Work from: /path/to/project
```
