#!/usr/bin/env python3
"""
PreToolUse Hook - Enforces language-specific skill invocation before code edits.

Reads configuration from ~/.config/agentic/hooks/skill-map.json (single source
of truth shared by Claude Code, Factory Droid CLI, and OpenCode).

Exit codes:
- 0: Allow the operation
- 2: Block the operation (returns deny with reason)
"""

import json
import sys
import re
from pathlib import Path

# ============================================================================
# Configuration - loaded from shared config
# ============================================================================

PROTECTED_TOOLS = {"Edit", "Write", "MultiEdit"}

CONFIG_PATH = Path.home() / ".config" / "agentic" / "hooks" / "skill-map.json"


def load_config() -> dict:
    """Load skill mapping from shared config file."""
    try:
        with open(CONFIG_PATH) as f:
            return json.load(f)
    except Exception as e:
        print(f"Warning: Could not load {CONFIG_PATH}: {e}", file=sys.stderr)
        return {}


def build_maps(config: dict) -> tuple:
    """
    Build runtime data structures from the shared config.

    Returns (extension_map, filename_patterns, ts_extensions, ts_config,
             security_skill, security_extensions, skip_extensions, bypass_patterns)
    """
    extension_map = config.get("extensions", {})
    filename_patterns = config.get("filename_patterns", {})
    ts_extensions = set(config.get("typescript_extensions", []))
    ts_config = config.get("typescript_config", {"skills": ["typescript-expert"], "label": "TypeScript/JavaScript"})
    security_skill = config.get("security_skill", "security-expert")
    security_extensions = set(config.get("security_extensions", []))
    skip_extensions = set(config.get("skip_extensions", []))
    bypass_patterns = config.get("bypass_patterns", [])

    return (extension_map, filename_patterns, ts_extensions, ts_config,
            security_skill, security_extensions, skip_extensions, bypass_patterns)


def read_transcript(transcript_path: str, max_entries: int = 500) -> list:
    """Read recent transcript entries."""
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


def find_invoked_skills(transcript_text: str) -> set[str]:
    """Find all skills that were invoked in the transcript."""
    skills = set()

    # Skill tool_use in transcript JSON
    for match in re.finditer(
        r'"name"\s*:\s*"Skill"[^}]*"skill"\s*:\s*"([^"]+)"',
        transcript_text,
    ):
        skills.add(match.group(1))

    # Skill invocation mentioned in text
    for match in re.finditer(
        r'(?:using|invok(?:ed|ing)|loaded?|applied?)\s+(?:the\s+)?["`\']?(\w[\w-]+)["`\']?\s+skill',
        transcript_text,
        re.IGNORECASE,
    ):
        skills.add(match.group(1))

    # Direct skill reference in skill tool input
    for match in re.finditer(
        r'"skill"\s*:\s*"([^"]+)"',
        transcript_text,
    ):
        skills.add(match.group(1))

    return skills


def get_required_skills(
    file_path: str,
    extension_map: dict,
    filename_patterns: dict,
    ts_extensions: set,
    ts_config: dict,
) -> tuple[list[str], str]:
    """Determine which skills are required for a given file."""
    path = Path(file_path)
    filename = path.name
    ext = path.suffix.lower()

    # Check filename patterns first (more specific)
    for pattern, config in filename_patterns.items():
        if re.search(pattern, filename):
            return config["skills"], config["label"]

    # Check extension map
    if ext in extension_map:
        config = extension_map[ext]
        return config["skills"], config["label"]

    # TypeScript/JavaScript
    if ext in ts_extensions:
        return ts_config["skills"], ts_config["label"]

    return [], ""


def check_bypass(transcript_text: str, bypass_patterns: list) -> tuple[bool, str]:
    """Check if user explicitly bypassed skill check."""
    for pattern in bypass_patterns:
        match = re.search(pattern, transcript_text, re.IGNORECASE)
        if match:
            return True, f"User bypass: '{match.group()}'"
    return False, ""


def main():
    """Main entry point for PreToolUse hook."""
    try:
        input_data = json.loads(sys.stdin.read(), strict=False)

        tool_name = input_data.get("tool_name", "")
        tool_input = input_data.get("tool_input", {})
        transcript_path = input_data.get("transcript_path", "")

        # Only check protected tools
        if tool_name not in PROTECTED_TOOLS:
            print(json.dumps({}))
            return

        # Get file path
        file_path = tool_input.get("file_path") or tool_input.get("filePath") or ""

        if not file_path:
            print(json.dumps({}))
            return

        # Load shared config
        config = load_config()
        if not config:
            print(json.dumps({}))
            return

        (extension_map, filename_patterns, ts_extensions, ts_config,
         security_skill, security_extensions, skip_extensions, bypass_patterns) = build_maps(config)

        # Skip non-code files
        ext = Path(file_path).suffix.lower()
        if ext in skip_extensions:
            print(json.dumps({}))
            return

        # Determine required skills
        required_skills, context_label = get_required_skills(
            file_path, extension_map, filename_patterns, ts_extensions, ts_config
        )

        if not required_skills:
            print(json.dumps({}))
            return

        # Need transcript to check
        if not transcript_path:
            print(json.dumps({}))
            print(
                f"Warning: No transcript path, skill check skipped for {context_label}",
                file=sys.stderr,
            )
            return

        # Read transcript
        entries = read_transcript(transcript_path)
        transcript_text = json.dumps(entries)

        # Check bypass
        bypassed, bypass_reason = check_bypass(transcript_text.lower(), bypass_patterns)
        if bypassed:
            print(json.dumps({}))
            print(f"Warning: Skill check bypass: {bypass_reason}", file=sys.stderr)
            return

        # Find invoked skills
        invoked = find_invoked_skills(transcript_text)

        # Check if any required skill was invoked
        matched = set(required_skills) & invoked

        if matched:
            print(json.dumps({}))
            print(
                f"OK: {context_label} skill active: {', '.join(sorted(matched))}",
                file=sys.stderr,
            )
            return

        # Security skill tip
        if ext in security_extensions and security_skill not in invoked:
            security_warning = (
                f"\n\nTIP: Also consider invoking '{security_skill}' "
                f"for security best practices."
            )
        else:
            security_warning = ""

        # No required skill invoked - BLOCK
        skills_str = ", ".join(f"'{s}'" for s in required_skills)

        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    f"BLOCKED: Language skill required before editing {context_label} file "
                    f"({Path(file_path).name}). Required: {skills_str}. "
                    f"See /language-skill-gate skill for mapping."
                ),
            }
        }

        print(json.dumps(output))
        print(
            f"BLOCKED: {context_label} file edit without skill "
            f"invocation ({skills_str})",
            file=sys.stderr,
        )
        sys.exit(2)

    except Exception as e:
        print(json.dumps({}))
        print(f"Warning: Skill hook error (allowing): {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
