# Scope Control

Implement the requested behavior as the single clear code path.

Do not add fallback functions, legacy compatibility layers, alternate implementations, adapter/shim paths, compatibility aliases, silent catch-and-substitute behavior, or duplicate old/new logic without explicit user approval.

If fallback, legacy, compatibility, adapter, shim, migration-preservation, or alternate-path code appears necessary, stop before implementing it and ask the user. The explanation must include:

- What fallback or compatibility path would be added
- Why the current requested implementation cannot work as a single path
- What risk or breakage the fallback is meant to prevent
- What code, tests, and maintenance burden the fallback would add
- The clean single-path alternative

Proceed only after the user explicitly chooses the fallback or compatibility approach.

This rule applies even when the agent believes a public API, platform support matrix, migration, release plan, or existing compatibility pattern might require fallback behavior. The agent may identify those facts as rationale, but must still ask first.

Prefer replacing the old path cleanly over keeping both paths. If the task explicitly asks to preserve compatibility, keep the compatibility surface minimal, documented, and tested.
