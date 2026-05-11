# Naming & Types

Evaluate whether names and types accurately communicate intent.

**The core question**: If a reader sees only the name or type, will their mental model match actual behavior? Names are micro-documentation. Types are contracts. When either lies, readers build wrong mental models and write bugs.

**What to look for**:

- Names that describe HOW instead of WHAT
- Verbs that lie (get that mutates, validate that parses)
- Missing domain types (primitives where concepts belong)
- Type-based branching (isinstance chains indicating missing polymorphism)
- Multiple names for the same concept within a file

**The threshold**: Flag only when name/type actively misleads or when domain concepts are hidden in primitives crossing boundaries. Imperfect-but-accurate names are style preferences, not quality issues.

---

## 1. Naming Precision

A name is micro-documentation. It should predict behavior accurately enough that reading the implementation confirms rather than surprises.

Detect: Does the name accurately describe what this does? Would a reader's mental model, built from the name alone, match actual behavior?

**Grep hints**: `Manager`, `Handler`, `Utils`, `Helper`, `Data`, `Info`, `process`, `handle`, `do`

**Violations**:

[high] Name-behavior mismatch
- Names describing HOW not WHAT (e.g., loopOverItems -> processOrders)
- Verbs that lie (e.g., get that mutates, validate that parses)
- Any name that would cause surprise when implementation is read

[medium] Abstraction leakage
- Implementation details in public API names
- Vague umbrella terms (e.g., Manager, Handler, Utils, Helper, Data, Info)

[low] Cognitive friction
- Negated booleans (e.g., isNotValid -> isInvalid, disableFeature -> featureEnabled)

**Exceptions**: Generic names in genuinely generic contexts (e.g., item in a generic collection, T in type params).

**Threshold**: Flag only when name actively misleads. Imperfect names that are still accurate are style preferences.

## 2. Missing Domain Modeling

Domain concepts should be explicit in code, not hidden in raw comparisons. When the same concept is checked multiple ways, it belongs in a domain object.

Detect: Are domain concepts hiding in raw conditions? Is the same business concept checked via primitive comparison in multiple places?

**Grep hints**: `== 'admin'`, `== "admin"`, `status ==`, `role ==`, `type ==`, magic numbers

**Violations**:

[high] Hidden domain logic
- Domain predicates in raw conditions (e.g., user.role == 'admin' -> user.can_edit())
- Magic value comparisons (e.g., status == 3 -> Status.APPROVED)
- Any business concept expressed only through primitive comparison

[medium] Implicit modeling
- String comparisons for state (e.g., mode == 'active' -> enum)
- Business rules buried in conditions (extract to domain object method)

**Exceptions**: Explicit comparisons in domain layer implementation itself. Config values compared once at startup.

**Threshold**: Flag when same domain concept is checked via raw comparison in 2+ places.

## 3. Type-Based Branching

Type dispatch scattered across code indicates missing polymorphism. When you branch on type in multiple places, the type itself should carry the behavior.

Detect: Is type-checking being used where polymorphism would be cleaner? Does the same type dispatch appear in multiple locations?

**Grep hints**: `isinstance`, `typeof`, `instanceof`, `hasattr`, `in dict`, `.type ==`

**Violations**:

[high] Scattered dispatch
- isinstance/typeof chains (3+ branches -> polymorphism candidate)
- Same type dispatch appearing in multiple locations

[medium] Implicit dispatch
- Attribute-presence checks (e.g., hasattr/in dict as type dispatch)

[low] Missing abstraction
- Duck typing conditionals that should be protocols/interfaces

**Exceptions**: Single isinstance check for input validation. Type narrowing for type safety.

**Threshold**: Flag when same type dispatch appears in 2+ places. Single-use type checks are often appropriate.

## 4. Type Design

Domain concepts deserve their own types. Primitives that cross boundaries without validation invite bugs; value objects with validation prevent them.

Detect: What domain concepts are represented as primitives? Do primitives cross API boundaries without validation?

**Grep hints**: `str` for IDs, `float` for money, `dict` passed through call chain, `Any`, `object`

**Violations**:

[high] Missing domain types
- Primitive obsession (e.g., userId as string -> UserId type with validation)
- Missing value objects (e.g., money as float -> Money(amount, currency))
- Any domain concept crossing API boundary as primitive

[medium] Weak typing
- Stringly-typed data (JSON strings -> typed objects)
- Leaky abstractions (callers must know implementation details)

[low] Type proliferation
- Optional explosion (many nullable fields -> consider separate types for states)

**Exceptions**: Primitives in internal implementation. Serialization boundaries. Performance-critical paths.

**Threshold**: Flag when primitives cross API boundaries without validation. Internal use of primitives is acceptable.

## 5. Naming Consistency (File Scope)

A concept should have one name within a file. Multiple names for the same thing create confusion about whether they're actually the same.

Detect: Are there multiple names for the same concept within this file? Would a reader wonder if user and account refer to the same entity?

**Grep hints**: Synonyms as variable prefixes (user/account/customer, config/settings/options, id/uid/identifier)

**Violations**:

[high] Semantic confusion
- Same entity called different names in same file (e.g., user vs account vs customer)
- Any naming inconsistency causing doubt about identity within a single file

[medium] Inconsistent conventions
- Inconsistent abbreviations within file (e.g., id vs identifier)

[low] Style drift
- Style inconsistency without semantic confusion

**Exceptions**: Different names for genuinely different concepts. External API naming conventions. Aliasing for clarity at specific scopes.

**Threshold**: Flag when same semantic concept has multiple names within a file AND causes confusion about whether they refer to the same thing.
