#!/usr/bin/env python3
"""
PreToolUse hook - blocks unapproved fallback/legacy compatibility code paths.

This enforces the shared scope-control convention before code edits. If an edit
appears to add fallback, legacy compatibility, adapter/shim, workaround, or
alternate implementation logic, the user must have explicitly approved that
direction first.
"""

import json
import re
import sys
from pathlib import Path
from typing import Any

PROTECTED_TOOLS = {"Edit", "Write", "MultiEdit", "edit", "write", "multi_edit", "apply_patch"}

CODE_EXTENSIONS = {
    ".bash",
    ".c",
    ".cc",
    ".cpp",
    ".cs",
    ".css",
    ".dart",
    ".fs",
    ".go",
    ".h",
    ".hpp",
    ".java",
    ".js",
    ".jsx",
    ".kt",
    ".php",
    ".py",
    ".rb",
    ".rs",
    ".sh",
    ".sql",
    ".svelte",
    ".swift",
    ".ts",
    ".tsx",
    ".vue",
    ".zsh",
}

SCOPE_PATTERNS = [
    r"fallback",
    r"\bfallback(s)?\b",
    r"\bfallback[_-]?(fn|function|handler|path|logic|mode|strategy)\b",
    r"legacy",
    r"\blegacy\b",
    r"compat",
    r"\bbackwards?\s+compat(ibility|ible)?\b",
    r"\bcompat(ibility)?\s+(layer|path|mode|alias|shim)\b",
    r"\badapter\s+(layer|path|shim|wrapper|for)\b",
    r"shim",
    r"\bshim(s|med|ming)?\b",
    r"polyfill",
    r"\bpolyfill(s)?\b",
    r"workaround",
    r"\bworkaround(s)?\b",
    r"\btemporary\s+(fix|solution|path|workaround)\b",
    r"\balternate\s+(implementation|path|flow|logic)\b",
    r"\bsecondary\s+(implementation|path|flow|logic)\b",
    r"\bsilent\s+catch\b",
    r"\bcatch\s+.*\b(fallback|default|ignore|swallow)\b",
    r"\bswallow\s+(error|exception|failure)s?\b",
    r"\btry\s+.*\bthen\s+fallback\b",
]

USER_APPROVAL_PATTERNS = [
    r"\b(approve|approved|allow|allowed|yes|ok|okay|go ahead|proceed)\b.{0,120}\b(fallback|legacy|compatibility|compatible|adapter|shim|workaround|alternate path)\b",
    r"\b(fallback|legacy|compatibility|compatible|adapter|shim|workaround|alternate path)\b.{0,120}\b(approve|approved|allowed|ok|okay|go ahead|proceed)\b",
    r"\b(implement|create|preserve|keep|support|maintain|use)\b.{0,80}\b(fallback|legacy|compatibility|compatible|adapter|shim|workaround|alternate path)\b",
    r"\b(fallback|legacy|compatibility|compatible|adapter|shim|workaround|alternate path)\b.{0,80}\b(implement|create|preserve|keep|support|maintain|use)\b",
]

USER_REJECTION_PATTERNS = [
    r"\b(no|without|avoid|do not|don't|dont|never)\b.{0,80}\b(fallback|legacy|compatibility|adapter|shim|workaround|alternate path)\b",
    r"\b(fallback|legacy|compatibility|adapter|shim|workaround|alternate path)\b.{0,80}\b(no|not allowed|forbidden|avoid|never)\b",
    r"\b(guard|guarding|block|blocking|prevent|preventing|stop|stopping|forbid|forbidding|disallow|disallowing)\b.{0,120}\b(fallback|legacy|compatibility|adapter|shim|workaround|alternate path)\b",
    r"\b(fallback|legacy|compatibility|adapter|shim|workaround|alternate path)\b.{0,120}\b(guard|guarding|block|blocking|prevent|preventing|stop|stopping|forbid|forbidding|disallow|disallowing)\b",
]


def is_code_file(file_path: str) -> bool:
    if not file_path:
        return True
    return Path(file_path).suffix.lower() in CODE_EXTENSIONS


def text_from_value(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return "\n".join(text_from_value(item) for item in value)
    if isinstance(value, dict):
        parts = []
        for key in ("text", "content", "message", "new_string", "old_string", "command"):
            if key in value:
                parts.append(text_from_value(value[key]))
        return "\n".join(parts)
    return ""


def proposed_edit_text(tool_input: dict[str, Any]) -> str:
    chunks = [
        text_from_value(tool_input.get("content")),
        text_from_value(tool_input.get("new_string")),
        text_from_value(tool_input.get("patch")),
        text_from_value(tool_input.get("input")),
        text_from_value(tool_input.get("command")),
    ]

    edits = tool_input.get("edits")
    if isinstance(edits, list):
        for edit in edits:
            if isinstance(edit, dict):
                chunks.append(text_from_value(edit.get("new_string")))

    return "\n".join(chunk for chunk in chunks if chunk)


def patch_targets_code(patch_text: str) -> bool:
    paths = []
    for match in re.finditer(r"^\*\*\* (?:Add|Update) File: (.+)$", patch_text, re.MULTILINE):
        paths.append(match.group(1).strip())

    if not paths:
        return True

    return any(is_code_file(path) for path in paths)


def added_lines_from_patch(patch_text: str) -> str:
    lines = []
    for line in patch_text.splitlines():
        if line.startswith("+") and not line.startswith("+++"):
            lines.append(line[1:])
    return "\n".join(lines)


def find_scope_term(text: str) -> str:
    for pattern in SCOPE_PATTERNS:
        match = re.search(pattern, text, re.IGNORECASE | re.DOTALL)
        if match:
            return match.group(0)
    return ""


def read_transcript_entries(transcript_path: str, max_entries: int = 800) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    if not transcript_path:
        return entries

    try:
        with open(transcript_path) as transcript:
            for index, line in enumerate(transcript):
                if index >= max_entries:
                    break
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(entry, dict):
                    entries.append(entry)
    except OSError:
        return []

    return entries


def entry_role(entry: dict[str, Any]) -> str:
    role = entry.get("role")
    if isinstance(role, str):
        return role

    message = entry.get("message")
    if isinstance(message, dict) and isinstance(message.get("role"), str):
        return message["role"]

    return ""


def user_text_from_entries(entries: list[dict[str, Any]]) -> str:
    chunks = []
    for entry in entries:
        if entry_role(entry).lower() != "user":
            continue
        chunks.append(text_from_value(entry))
    return "\n".join(chunks).lower()


def has_user_approval(user_text: str) -> bool:
    if not user_text:
        return False

    for pattern in USER_REJECTION_PATTERNS:
        if re.search(pattern, user_text, re.IGNORECASE | re.DOTALL):
            return False

    return any(
        re.search(pattern, user_text, re.IGNORECASE | re.DOTALL)
        for pattern in USER_APPROVAL_PATTERNS
    )


def deny(reason: str) -> None:
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }
    print(json.dumps(output))
    print(reason, file=sys.stderr)
    sys.exit(2)


def main() -> None:
    try:
        input_data = json.loads(sys.stdin.read(), strict=False)
    except json.JSONDecodeError:
        print(json.dumps({}))
        return

    tool_name = input_data.get("tool_name") or input_data.get("tool") or ""
    if tool_name not in PROTECTED_TOOLS:
        print(json.dumps({}))
        return

    metadata = input_data.get("metadata")
    if not isinstance(metadata, dict):
        metadata = {}
    tool_input = input_data.get("tool_input") or input_data.get("args") or metadata.get("args") or {}
    if not isinstance(tool_input, dict):
        print(json.dumps({}))
        return

    file_path = tool_input.get("file_path") or tool_input.get("filePath") or tool_input.get("path") or ""
    if file_path and not is_code_file(str(file_path)):
        print(json.dumps({}))
        return

    patch_text = text_from_value(tool_input.get("patch") or tool_input.get("input"))
    if tool_name == "apply_patch" and patch_text and not patch_targets_code(patch_text):
        print(json.dumps({}))
        return

    edit_text = added_lines_from_patch(patch_text) if patch_text else proposed_edit_text(tool_input)
    matched_term = find_scope_term(edit_text)
    if not matched_term:
        print(json.dumps({}))
        return

    entries = read_transcript_entries(str(input_data.get("transcript_path", "")))
    if has_user_approval(user_text_from_entries(entries)):
        print(json.dumps({}))
        print(f"✓ Scope-control approval found for term: {matched_term}", file=sys.stderr)
        return

    deny(
        "🛑 BLOCKED: Proposed edit appears to add fallback/legacy/compatibility "
        f"logic (`{matched_term}`) without explicit user approval. Ask the user first "
        "and explain the proposed path, why a single-path implementation is insufficient, "
        "the risk it prevents, the maintenance burden it adds, and the clean single-path alternative."
    )


if __name__ == "__main__":
    main()
