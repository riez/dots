#!/usr/bin/env python3
"""
PreToolUse Hook - Enforces mandatory todo/plan creation before code changes.

This hook fires BEFORE Edit, Write, or MultiEdit tools execute. It checks
the session transcript to verify that a plan/todo was created first.

The rationale: If no plan exists, the agent doesn't understand the big picture
and may be making changes without thinking through the full scope.

Exit codes:
- 0: Allow the operation
- 2: Block the operation (returns deny with reason)

The hook allows bypass if:
- User explicitly says "skip planning" or "single change" or "one line fix"
- The change is truly trivial (user provides exact file + line + change)
"""

import json
import sys
import re
from pathlib import Path

# ============================================================================
# Configuration
# ============================================================================

# Tools that require prior planning
PROTECTED_TOOLS = {"Edit", "Write", "MultiEdit"}

# Patterns that indicate a todo/plan was created
PLAN_PATTERNS = [
    r"TodoWrite",
    r"update_plan",
    r"mcp_todowrite",
    r'"status":\s*"in_progress"',
    r'"status":\s*"pending"',
    r'"content":\s*"[^"]+",\s*"status"',  # Todo item structure
    r"## (Plan|Todo|Tasks)",
    r"### Steps",
    r"todo.*created",
    r"plan.*created",
    r"creating.*todo",
    r"creating.*plan",
]

# Patterns that indicate user explicitly bypassed planning
BYPASS_PATTERNS = [
    r"skip\s+plan(ning)?",
    r"no\s+(need\s+(for\s+)?)?plan",
    r"bypass\s+plan(ning)?",
    r"just\s+do\s+it",
    r"single\s+(change|edit|fix)",
    r"one\s+line\s+(change|fix|edit)",
    r"quick\s+fix",
    r"trivial\s+(change|fix|edit)",
]

# Patterns that indicate full context was provided (strengthens bypass)
FULL_CONTEXT_PATTERNS = [
    r"line\s+\d+",
    r"at\s+line",
    r"on\s+line",
    r":\d+",  # file:line format
]

# File extensions that are considered code (need planning)
CODE_EXTENSIONS = {
    ".py",
    ".js",
    ".ts",
    ".jsx",
    ".tsx",
    ".vue",
    ".svelte",
    ".go",
    ".rs",
    ".rb",
    ".php",
    ".java",
    ".kt",
    ".swift",
    ".c",
    ".cpp",
    ".h",
    ".hpp",
    ".cs",
    ".fs",
    ".sh",
    ".bash",
    ".zsh",
    ".fish",
    ".sql",
    ".graphql",
    ".prisma",
    ".yaml",
    ".yml",
    ".toml",
    ".json",
    ".xml",
    ".css",
    ".scss",
    ".sass",
    ".less",
    ".html",
    ".htm",
    ".md",
    ".mdx",
}

# Files that are always safe to edit without planning
SAFE_FILES = {
    ".gitignore",
    ".env.example",
    "LICENSE",
    "CHANGELOG.md",
}


def is_code_file(file_path: str) -> bool:
    """Check if the file is a code file that requires planning."""
    path = Path(file_path)
    if path.name in SAFE_FILES:
        return False
    return path.suffix.lower() in CODE_EXTENSIONS


def read_transcript(transcript_path: str, max_entries: int = 500) -> list:
    """Read recent transcript entries to check for planning."""
    entries = []
    try:
        with open(transcript_path, "r") as f:
            for i, line in enumerate(f):
                if i >= max_entries:
                    break
                try:
                    entries.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    except Exception:
        pass
    return entries


def check_plan_created(transcript_text: str) -> tuple[bool, str]:
    """Check if a todo/plan was created in this session."""
    for pattern in PLAN_PATTERNS:
        if re.search(pattern, transcript_text, re.IGNORECASE):
            return True, "plan/todo was created"
    return False, "no plan/todo was created - agent may not understand the big picture"


def check_explicit_bypass(transcript_text: str) -> tuple[bool, str]:
    """Check if user explicitly requested bypass for planning."""
    has_bypass_request = any(
        re.search(pattern, transcript_text, re.IGNORECASE)
        for pattern in BYPASS_PATTERNS
    )

    if not has_bypass_request:
        return False, "no planning bypass requested"

    # For planning, we're more lenient - bypass phrase alone is enough
    # But we note if full context was provided
    has_full_context = any(
        re.search(pattern, transcript_text, re.IGNORECASE)
        for pattern in FULL_CONTEXT_PATTERNS
    )

    if has_full_context:
        return True, "user explicitly bypassed planning with full context"
    else:
        return True, "user explicitly bypassed planning (single/trivial change)"


def main():
    """Main entry point for PreToolUse hook."""
    try:
        input_data = json.loads(sys.stdin.read(), strict=False)

        tool_name = input_data.get("tool_name", "")
        tool_input = input_data.get("tool_input", {})
        transcript_path = input_data.get("transcript_path", "")

        # If no transcript path provided, we can't check - allow with warning
        if not transcript_path:
            print(json.dumps({}))
            print(
                "⚠️ No transcript path provided, planning check skipped", file=sys.stderr
            )
            return

        # Only check protected tools
        if tool_name not in PROTECTED_TOOLS:
            print(json.dumps({}))
            return

        # Get file path from tool input
        file_path = tool_input.get("file_path") or tool_input.get("filePath") or ""

        # Skip non-code files
        if file_path and not is_code_file(file_path):
            print(json.dumps({}))
            print(
                f"✓ {file_path} is not a code file, planning not required",
                file=sys.stderr,
            )
            return

        # Read transcript
        entries = read_transcript(transcript_path)
        transcript_text = json.dumps(entries).lower()

        # Check if plan was created
        has_plan, plan_reason = check_plan_created(transcript_text)

        if has_plan:
            print(json.dumps({}))
            print(f"✓ {plan_reason}", file=sys.stderr)
            return

        # Plan NOT created - check for valid bypass
        bypassed, bypass_reason = check_explicit_bypass(transcript_text)

        if bypassed:
            print(json.dumps({}))
            print(f"⚠️ Allowing without plan: {bypass_reason}", file=sys.stderr)
            return

        # Neither planned nor valid bypass - BLOCK
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    f"🛑 BLOCKED: Plan before editing. "
                    f"See /mandatory-workflow skill for full procedure."
                ),
            }
        }

        print(json.dumps(output))
        print(f"🛑 BLOCKED: {plan_reason}", file=sys.stderr)
        sys.exit(2)

    except Exception as e:
        print(json.dumps({}))
        print(f"⚠️ Hook error (allowing): {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
