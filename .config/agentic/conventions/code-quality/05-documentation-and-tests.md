# Documentation & Tests

Evaluate whether code is properly documented and tested.

**The core question**: Is this documented and tested? Documentation that contradicts code is worse than no documentation. Tests that don't communicate behavior fail as documentation. Schema drift causes runtime errors. Generated code without provenance documentation misleads maintainers.

**What to look for**:

- Documentation contradicting actual code
- Tests with uninformative names
- Missing provenance for generated/vendored code in CLAUDE.md
- Schema-code mismatches (fields in code missing from schema, or vice versa)

**The threshold**: Flag only demonstrable incorrectness, not incompleteness. Stale docs cause hallucinations; missing docs just mean less context. Flag tests that give no behavioral information. Flag generated/vendored code without CLAUDE.md documentation. Flag schema drift only when provable mismatch exists.

---

## 1. Documentation Staleness

Documentation that contradicts code is worse than no documentation. Stale docs mislead readers and cause bugs.

Detect: Does the documentation contradict the code? Are there claims in docs that the code structurally violates?

**Grep hints**: Docstrings with parameter names, @param, @return, TODO, FIXME

**Violations**:

[high] Active contradictions
- Parameter name in docstring not in function signature
- Docstring type conflicts with type annotation (when annotation exists)
- Any documentation making claims the code structurally contradicts

[medium] Stale claims
- Docstring describes return value that code never returns
- Comment contains strong claim ("always", "never", "must") AND code structurally contradicts it

[low] Orphaned references
- TODO/FIXME referencing completed or removed work

**Exceptions**: Incomplete documentation. Missing docs. Outdated style in docs.

**Threshold**: Flag only when documentation is demonstrably incorrect, not merely incomplete. Incorrect documentation causes hallucinations.

## 2. Test Quality as Documentation

Tests document expected behavior. When test names don't communicate what behavior they verify, they fail as documentation.

Detect: Do tests communicate expected behavior? Can I understand what's being tested from the test name alone?

**Grep hints**: `test_works`, `test_ok`, `test_success`, `test_case_`, `test_1`, `assert True`

**Violations**:

[high] Uninformative tests
- Test name matches low-information pattern (e.g., test_works, test_ok, test_success, test_case_1)
- Test contains 0 assertions
- Any test where the name gives no behavioral information

[medium] Weak naming
- Test name shorter than 3 tokens (excluding test\_ prefix)
- Test name describes implementation, not behavior

[low] Test smells
- Test only asserts True, None, or trivial values
- Multiple similar test functions with minor input variations (use parameterized/table-driven)

**Exceptions**: Tests referencing ticket numbers (e.g., TEST-1234, JIRA-567) for traceability. Smoke tests named test_works.

**Threshold**: Flag when test name gives no behavioral information AND is not a ticket/regression reference.

## 3. Generated and Vendored Code Awareness

Non-maintainable code (generated, vendored) must be clearly marked. Without provenance documentation, maintainers may try to modify code that should be regenerated.

Detect: Is non-maintainable code clearly marked in CLAUDE.md? Can a maintainer tell which code is generated or vendored?

**Grep hints**: `_generated`, `_pb`, `.pb.go`, `vendor/`, `third_party/`, `node_modules/`

**Violations**:

[high] Missing provenance
- Generated files missing regeneration command in CLAUDE.md
- Vendored directories missing upstream source in CLAUDE.md
- Any generated/vendored code without documentation of origin

[medium] Unclear ownership
- External libraries copied into repo without provenance documentation

**Exceptions**: Generated files with regeneration command documented. Vendored code with clear upstream reference.

**Threshold**: Flag when file/directory matches generation patterns (e.g., *.pb.go, *_generated.*, vendor/, third_party/) AND CLAUDE.md lacks corresponding entry explaining provenance.

## 4. Schema-Code Coherence

Schema and code must stay synchronized. Fields referenced in code but absent from schema (or vice versa) indicate drift that causes runtime errors.

Detect: Does code reference schema fields that don't exist? Are there schema fields unused in any code path?

**Grep hints**: Schema file extensions (.proto, .graphql, .json schema), field access patterns

**Violations**:

[high] Schema drift
- Code references field not in schema definition
- Schema field unused in any code path (dead field)
- Any mismatch between schema definition and code usage

[medium] Type drift
- Type mismatch between schema and code representation

**Exceptions**: Intentional divergence documented with :SCHEMA: marker. Fields used only in specific deployment configs.

**Threshold**: Flag when field name in code has 0 matches in corresponding schema file, or schema field has 0 references in codebase.

Intent marker: Use `:SCHEMA:` to suppress for intentional divergence (e.g., `:SCHEMA: field 'legacy_id' unused; migration pending`).
