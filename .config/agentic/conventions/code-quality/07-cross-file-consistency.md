# Cross-File Consistency

Evaluate whether patterns are consistent across files.

**The core question**: Is this consistent across files? Similar APIs should behave similarly. The same concept should have one name throughout the codebase. Error handling should be predictable at each abstraction level. Feature flags should be evaluated consistently.

**What to look for**:

- Cross-module naming drift (userId/uid/id for same concept)
- Incompatible signatures for similar operations across modules
- Cross-abstraction-level error pattern inconsistency
- Feature flags checked with different logic in different places

**The threshold**: Flag when inconsistency creates confusion or unpredictability for consumers. Flag when same concept has multiple names across modules AND causes integration confusion. This group requires seeing multiple files to detect patterns.

---

## 1. Interface Consistency

Similar APIs should have consistent signatures. When similar functions surprise users with different conventions, they cause bugs.

Detect: Would a user of these APIs be surprised by inconsistency? Do similar operations have incompatible signatures?

**Grep hints**: Similar function signatures with different parameter orders, CRUD operation patterns, service method signatures

**Violations**:

[high] Signature inconsistency
- APIs with similar purposes have incompatible signatures AND share consumers
- Any API inconsistency causing caller confusion

[medium] Naming inconsistency
- Inconsistent naming conventions across related functions

[low] Pattern inconsistency
- Mixed sync/async for similar operations without clear reason

**Exceptions**: Intentional API differences. Domain-specific conventions. Versioned APIs. Overloads with clear distinct purpose.

**Threshold**: Flag when 2+ similar functions have different parameter orders (file scope) or 3+ APIs have incompatible signatures (codebase scope) AND confusion impacts consumers.

## 2. Naming Consistency (Cross-File Scope)

A concept should have one name throughout the codebase. Multiple names for the same thing create confusion about whether they're actually the same.

Detect: Are there multiple names for the same concept across modules? Would a reader wonder if userId and uid refer to the same entity?

**Grep hints**: Synonyms as variable prefixes across modules (user/account/customer, config/settings/options, id/uid/identifier)

**Violations**:

[high] Semantic confusion
- Synonym drift causing confusion at integration points
- Any naming inconsistency causing doubt about identity across modules

[medium] Inconsistent conventions
- Inconsistent abbreviations across modules (e.g., userId vs uid vs id)

[low] Style drift
- Style inconsistency without semantic confusion

**Exceptions**: Different names for genuinely different concepts. External API naming conventions. Domain-specific terminology. Legacy compatibility aliases in bounded migration.

**Threshold**: Flag when same semantic concept has 3+ different names across modules AND causes confusion about whether they refer to the same thing.

## 3. Error Pattern Consistency (Cross-File Scope)

Error handling should be consistent within an abstraction level. Mixed patterns create confusion about how errors propagate and should be handled.

Detect: Is error handling consistent across components at the same abstraction level? Would a caller know what to expect from similar operations?

**Grep hints**: Mixed exception/return-code patterns, inconsistent error message formats, varying error context across modules

**Violations**:

[high] Incompatible patterns
- Incompatible error patterns for similar operations across components
- Any error handling creating caller confusion at integration boundaries

[medium] Inconsistent hierarchy
- Inconsistent exception hierarchies at same abstraction level

[low] Missing convention
- No standard for error context/wrapping across modules

**Exceptions**: Different patterns for different abstraction levels (domain vs API vs infra). Wrapper functions translating between error styles. Legacy code under active migration.

**Threshold**: Flag when same abstraction level uses 3+ incompatible error patterns across files for similar operations AND no migration plan exists.

## 4. Feature Flag Sprawl

Feature flags should be checked consistently. When the same flag is evaluated with different logic in different places, behavior becomes unpredictable.

Detect: How are feature flags checked across the codebase? Is the same flag evaluated consistently everywhere?

**Grep hints**: Feature flag checks, toggle patterns, conditional feature code

**Violations**:

[high] Inconsistent evaluation
- Feature flags checked inconsistently (different conditions for same flag)
- Any flag with divergent evaluation logic across locations

[medium] Undocumented dependencies
- Flag dependencies not documented (flag A requires flag B)

**Exceptions**: Flags with intentionally different behavior per context. A/B test variations. Gradual rollout logic.

**Threshold**: Flag when same feature flag is checked with different logic in different places AND the difference is unintentional.

Note: Dead flags (feature shipped, never removed) are covered in 08-codebase-patterns.md Zombie Code (Codebase Scope).
