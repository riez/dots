# Codebase Patterns

Evaluate patterns that only emerge from codebase-wide analysis.

**The core question**: What patterns are emerging? Understanding should not require reading the entire codebase. Repeated patterns across files indicate missing abstractions. Dead exports and modules accumulate as noise. These issues are invisible in local review -- they only become visible when seeing the whole codebase.

**What to look for**:

- Flows requiring 5+ files to understand with no documentation
- Same transformation applied in 3+ files (missed abstraction)
- Exported functions with 0 callers anywhere
- Feature flags always true/false (never toggled)
- Dead modules with no imports from live code

**The threshold**: Flag when comprehension is broken (5+ files, no guide). Flag when pattern appears in 3+ implementations AND extraction would help. Flag demonstrably dead code that's not a public API or plugin interface. This group requires whole-codebase visibility.

---

## 1. Cross-File Comprehension

Understanding a flow should not require reading the entire codebase. When grasping one operation requires 5+ files with no guide, comprehension is broken.

Detect: How many files must I read to understand this flow? Is there documentation or an orchestrator that explains the big picture?

**Grep hints**: Call chains, event handlers, callback registrations

**Violations**:

[high] Implicit contracts
- Implicit contracts between files (caller must know callee internals)
- Any flow requiring undocumented assumptions to understand

[medium] Hidden dependencies
- Hidden dependencies (file A assumes file B ran first)

[low] Scattered flow
- Scattered control flow (one operation spans 5+ files with no orchestrator)

**Exceptions**: Well-documented module boundaries. Plugin architectures. Event-driven designs with clear event contracts.

**Threshold**: Flag when understanding a single operation requires reading 5+ files with no documentation of the flow.

## 2. Abstraction Opportunities

Repeated patterns across files indicate missing abstractions. When you see the same transformation in 3+ places, a concept is trying to emerge.

Detect: What domain concept is hiding across these repeated patterns? Would extracting a shared abstraction reduce duplication?

**Grep hints**: Parallel implementations, similar transformation chains, repeated configuration shapes

**Violations**:

[high] Missed abstractions
- Same transformation applied in multiple files (3+ occurrences)
- Any pattern appearing across implementations that should be shared

[medium] Structural duplication
- Parallel class hierarchies doing similar things differently
- Copy-paste inheritance (similar classes with minor variations)

[low] Configuration patterns
- Data transformation pipelines with identical structure
- Configuration patterns repeated without abstraction

**Exceptions**: Intentionally similar but independent implementations. Domain-specific variations. Templates/generators producing similar code.

**Threshold**: Flag when pattern appears in 3+ implementations AND the fix is extracting shared abstraction. These become visible only after seeing multiple implementations.

## 3. Zombie Code (Codebase Scope)

Dead code is noise that misleads readers. Code that cannot execute or is never called should be removed, not left to confuse future maintainers.

Detect: If I deleted this export or module, would any test fail or behavior change?

**Grep hints**: Exported symbols with 0 callers, feature flags, configuration options, dead modules

**Violations**:

[high] Dead exports
- Exported functions with 0 callers anywhere in codebase
- Feature flags always true/false (never toggled in any environment)
- Any publicly accessible code with no consumers

[medium] Stale flags
- Dead flags (feature shipped, flag never removed)

[low] Orphaned configuration
- Configuration options never read
- Dead modules (no imports from any live code path)

**Exceptions**: Public API entry points. Plugin interfaces. Feature flags controlled externally. Backward compatibility exports with deprecation notice.

**Threshold**: Flag when code is demonstrably unreachable/unused AND is not a public API entry point, plugin interface, or documented compatibility shim.

Note: File-scope zombie code (commented blocks, unreachable branches) is covered in 03-patterns-and-idioms.md Zombie Code (File Scope).
