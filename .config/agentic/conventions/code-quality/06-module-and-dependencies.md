# Module & Dependencies

Evaluate whether module boundaries are clean and architecture aligns with change patterns.

**The core question**: Are boundaries clean? Modules should have clear boundaries with minimal coupling. Architecture should align with how features actually change. When changes ripple across unrelated modules or require touching many components, the boundaries are wrong.

**What to look for**:

- Circular dependencies
- Layer violations (domain importing infrastructure)
- Wrong component boundaries (features awkwardly split)
- Architecture forcing cross-cutting changes for single-domain features

**The threshold**: Flag when dependencies cause compilation issues or domain corruption. Flag when adding a feature requires touching many unrelated components. This is inherently about relationships between files and modules, not local code patterns.

---

## 1. Module Structure

Modules should have clear boundaries with minimal coupling. When changes ripple across unrelated modules, the boundaries are wrong.

Detect: Do changes ripple to unrelated modules? Can a module be modified without understanding its dependents?

**Grep hints**: Import graphs, dependency declarations, module boundaries

**Violations**:

[high] Structural violations
- Circular dependencies (e.g., A imports B imports A)
- Layer violations (e.g., domain importing infrastructure)
- Any dependency causing compilation order issues or domain corruption

[medium] Cohesion problems
- Wrong cohesion (unrelated things grouped in same module)
- Missing facades (module internals exposed directly)

[low] Scope creep
- God modules (too many responsibilities in one module)

**Exceptions**: Circular deps within same bounded context. Infrastructure adapters importing domain. Shared kernel patterns.

**Threshold**: Flag when dependency causes compilation order issues OR when layer violation allows infrastructure to corrupt domain.

## 2. Architecture

Architecture should align with change patterns. When adding a feature requires touching many unrelated components, the architecture fights the domain.

Detect: Would adding a feature require touching many components? Do cross-cutting changes indicate misaligned boundaries?

**Grep hints**: Component boundaries, service interfaces, configuration locations

**Violations**:

[high] Boundary misalignment
- Wrong component boundaries (features awkwardly split)
- Single points of failure (no fallback, no retry paths)
- Any architecture forcing cross-cutting changes for single-domain features

[medium] Scaling issues
- Scaling bottlenecks (synchronous where async needed)
- Monolith patterns in distributed code (or vice versa)

[low] Missing structure
- Missing abstraction layers (everything directly coupled)
- Configuration scattered (no central policy, settings in many places)

**Exceptions**: Intentional coupling for simplicity. Early-stage monolith. Bounded contexts with shared kernel.

**Threshold**: Flag when architecture forces cross-cutting changes for single-domain features.
