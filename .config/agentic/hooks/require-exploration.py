#!/usr/bin/env python3
"""
PreToolUse Hook - Enforces mandatory code-explorer dispatch before code changes.

This hook fires BEFORE Edit, Write, or MultiEdit tools execute. It checks
the session transcript to verify that code-explorer was dispatched first.

Exit codes:
- 0: Allow the operation
- 2: Block the operation (returns deny with reason)

The hook allows bypass ONLY if user explicitly said "skip exploration" AND
provided full context (file path, line number, exact change).
"""

import json
import sys
import re
from pathlib import Path

# ============================================================================
# Configuration
# ============================================================================

# Tools that require prior exploration
PROTECTED_TOOLS = {"Edit", "Write", "MultiEdit"}

# Patterns that indicate code-explorer was used
EXPLORER_PATTERNS = [
    r"code-explorer",  # Direct mention
    r"@superpowers:code-explorer",  # @mention format
    r"subagent_type.*code-explorer",  # Task tool parameter
    r"subagent_type.*explore",  # Generic explore agent
    r"dispatching.*code-explorer",  # Dispatching message
    r"dispatching.*explorer",  # Dispatching explorer
    r"code-explorer.*returned",  # Return message
    r"SLICE.*output",  # SLICE output (from any explorer)
    r"explore.*codebase",  # Exploration language
    r"explored.*code",  # Past tense
    r"mcp_task.*explore",  # Task tool with explore
    r'"description".*[Ee]xplore',  # Task description
]

# Patterns that indicate user explicitly bypassed exploration
BYPASS_PATTERNS = [
    r"skip\s+exploration",
    r"work\s+directly",
    r"no\s+need\s+(for\s+)?exploration",
    r"bypass\s+exploration",
    r"already\s+(know|understand|explored)",
    r"i\s+know\s+(where|what|how)",
    r"simple\s+(change|edit|fix)",
    r"obvious\s+(change|edit|fix)",
]

# Patterns that indicate full context was provided (required for bypass)
FULL_CONTEXT_PATTERNS = [
    r"line\s+\d+",
    r"at\s+line",
    r"on\s+line",
    r":\d+",  # file:line format
]

# File extensions that are considered code (need exploration)
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

# Files that are always safe to edit without exploration
SAFE_FILES = {
    ".gitignore",
    ".env.example",
    "LICENSE",
    "CHANGELOG.md",
}


def is_code_file(file_path: str) -> bool:
    """Check if the file is a code file that requires exploration."""
    path = Path(file_path)
    if path.name in SAFE_FILES:
        return False
    return path.suffix.lower() in CODE_EXTENSIONS


def read_transcript(transcript_path: str, max_entries: int = 500) -> list:
    """Read recent transcript entries to check for exploration."""
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


def check_exploration_done(transcript_text: str) -> tuple[bool, str]:
    """Check if code-explorer was dispatched in this session."""
    for pattern in EXPLORER_PATTERNS:
        if re.search(pattern, transcript_text, re.IGNORECASE):
            return True, "code-explorer was dispatched"
    return False, "code-explorer was NOT dispatched before code changes"


def check_explicit_bypass(transcript_text: str) -> tuple[bool, str]:
    """Check if user explicitly requested bypass WITH full context."""
    has_bypass_request = any(
        re.search(pattern, transcript_text, re.IGNORECASE)
        for pattern in BYPASS_PATTERNS
    )

    if not has_bypass_request:
        return False, "no bypass requested"

    has_full_context = any(
        re.search(pattern, transcript_text, re.IGNORECASE)
        for pattern in FULL_CONTEXT_PATTERNS
    )

    if has_full_context:
        return True, "user explicitly bypassed with full context"

    return False, "bypass requested but missing full context (file path + line number)"


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
                "⚠️ No transcript path provided, exploration check skipped",
                file=sys.stderr,
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
                f"✓ {file_path} is not a code file, exploration not required",
                file=sys.stderr,
            )
            return

        # Read transcript
        entries = read_transcript(transcript_path)
        transcript_text = json.dumps(entries).lower()

        # Check if exploration was done
        explored, explore_reason = check_exploration_done(transcript_text)

        if explored:
            print(json.dumps({}))
            print(f"✓ {explore_reason}", file=sys.stderr)
            return

        # Exploration NOT done - check for valid bypass
        bypassed, bypass_reason = check_explicit_bypass(transcript_text)

        if bypassed:
            print(json.dumps({}))
            print(f"⚠️ Allowing code change: {bypass_reason}", file=sys.stderr)
            return

        # Neither explored nor valid bypass - BLOCK
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    f"🛑 BLOCKED: Explore before editing. "
                    f"See /mandatory-workflow skill for full procedure."
                ),
            }
        }

        print(json.dumps(output))
        print(f"🛑 BLOCKED: {explore_reason}", file=sys.stderr)
        sys.exit(2)

    except Exception as e:
        print(json.dumps({}))
        print(f"⚠️ Hook error (allowing): {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
