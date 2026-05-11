# Repetition & Consistency

Evaluate whether code follows DRY principles and maintains consistency.

**The core question**: Is this DRY and consistent? When the same logic, validation, or pattern appears in multiple places, bugs must be fixed everywhere -- and they won't be. When similar operations use different patterns, readers question whether the difference is meaningful.

**What to look for**:

- Duplicated code blocks that would require multi-location bug fixes
- Validation rules implemented multiple times
- Business rules scattered across locations
- Repeated boolean expressions
- Inconsistent error handling within a file or class

**The threshold**: Flag when duplication is unintentional and would require coordinated changes. Flag inconsistency when it creates confusion about whether the difference is meaningful. Intentional duplication for modularity or bounded context isolation is acceptable.

---

## 1. Duplication

Code should have a single source of truth. When the same logic exists in multiple places, bugs must be fixed everywhere -- and they won't be.

Detect: If I fixed a bug here, where else would I need to fix it?

**Grep hints**: Identical multi-line blocks, similar function bodies, function names suggesting similar purpose across modules

**Violations**:

[high] Direct duplication
- Same code block duplicated (3+ lines, logic not just boilerplate)
- Any logic that would require multi-location bug fixes

[medium] Near-duplication
- Copy-paste with minor variations

[low] Missed abstraction
- Common pattern not extracted to shared location

**Exceptions**: Intentionally different logic serving different purposes. Test setup code. Generated/vendored code. Deliberate isolation for modularity. Similar code in different bounded contexts.

**Threshold**: Flag when bug fix would require changing multiple locations AND the duplication is unintentional.

## 2. Validation Scattering

Validation rules should live in one place. When the same validation is implemented multiple times, implementations diverge -- and some will be wrong.

Detect: Is this validation duplicated? Would changing the validation rule require updating multiple locations?

**Grep hints**: Repeated regex patterns, duplicate bounds checks, email/phone/format validation across locations

**Violations**:

[high] Diverged validation
- Validation rules diverged between implementations
- Any validation requiring multi-location updates

[medium] Repeated validation
- Same validation repeated without shared implementation

[low] Defensive re-validation
- Defensive re-validation deeper in call chain

**Exceptions**: Validation at trust boundaries. Defense-in-depth by design. Context-specific validation rules. Service boundary validation.

**Threshold**: Flag when identical validation appears 3+ times (file scope) or 5+ files (codebase scope) AND implementations have diverged or will diverge.

## 3. Business Rule Scattering

Business rules should have a single source of truth. When the same decision is made in multiple places, they will eventually disagree.

Detect: Where is the single source of truth for this rule? If the rule changes, how many places need updating?

**Grep hints**: Repeated conditional patterns, magic numbers in multiple places, pricing/permission/eligibility logic

**Violations**:

[high] Scattered decisions
- Same business decision in multiple places that could diverge
- Any business rule without clear single source of truth

[medium] Mixed concerns
- Business logic mixed with infrastructure code

[low] Implicit rules
- Rules embedded in raw conditionals instead of named predicates

**Exceptions**: Orchestration calling multiple rule checks. Rules intentionally duplicated for service isolation. Per-tenant/region rule variations. Caching of computed rules.

**Threshold**: Flag when same business decision is made in 2+ places (file scope) or 3+ files (codebase scope) AND they have diverged or could diverge independently.

## 4. Condition Pattern Repetition

Repeated boolean expressions should be named predicates. When the same condition appears everywhere, changing it requires finding all occurrences.

Detect: Should this condition be a named predicate? Does extracting it reduce the bug surface area?

**Grep hints**: Identical boolean expressions, repeated guard clauses, permission/feature-flag check patterns

**Violations**:

[high] High-frequency repetition
- Identical condition in 3+ places (file) or 5+ files (codebase) (extracting reduces bug surface)
- Any condition requiring multi-location updates when logic changes

[medium] Pattern repetition
- Repeated feature flag conditions

[low] Guard repetition
- Same guard clause pattern across related functions

**Exceptions**: Standard guard clauses (null checks, bounds checks). Framework-required patterns. Simple conditions that read clearly inline.

**Threshold**: Flag when identical condition appears 3+ times (file scope) or 5+ files (codebase scope) AND extracting to named predicate would reduce bug surface area.

## 5. Error Pattern Consistency (File Scope)

Error handling should be consistent within an abstraction level. Mixed patterns create confusion about how errors propagate and should be handled.

Detect: Is error handling consistent within this file or class? Would a caller know what to expect from similar operations?

**Grep hints**: Mixed exception/return-code patterns, inconsistent error message formats, varying error context

**Violations**:

[high] Incompatible patterns
- Incompatible error patterns for similar operations within same class
- Any error handling creating caller confusion

[medium] Inconsistent hierarchy
- Inconsistent exception hierarchies within same abstraction level

[low] Missing convention
- No standard for error context/wrapping within file

**Exceptions**: Different patterns for different abstraction levels (domain vs API vs infra). Wrapper functions translating between error styles. Legacy code under active migration.

**Threshold**: Flag when same class uses 2+ incompatible error patterns for similar operations AND no migration plan exists.
