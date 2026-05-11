#!/usr/bin/env python3
"""
CodeRabbit Review Integration Hook

Modes:
  post-edit:   PostToolUse after Write/Edit/MultiEdit - tracks changes only.
  pre-commit:  PreToolUse before Execute - gates git commit on a completed
               `coderabbit review --prompt-only` run by the agent.
  mark-done:   Called after the agent runs `coderabbit review` via Execute -
               marks the review as completed and captures output.

The agent is responsible for explicitly running `coderabbit review` before
committing.  This hook never starts background processes.

State tracked in /tmp/factory-coderabbit-{project_hash}/
"""

import json
import sys
import os
import hashlib
import re
from pathlib import Path

STATE_DIR_BASE = "/tmp/factory-coderabbit"


def get_state_dir():
    project_dir = os.environ.get("FACTORY_PROJECT_DIR", os.getcwd())
    dir_hash = hashlib.md5(project_dir.encode()).hexdigest()[:12]
    state_dir = Path(f"{STATE_DIR_BASE}-{dir_hash}")
    state_dir.mkdir(parents=True, exist_ok=True)
    return state_dir, project_dir


def load_state(state_dir):
    state_file = state_dir / "state.json"
    default = {
        "review_status": "none",  # none | completed
        "review_stale": False,
        "findings_injected": False,
        "edit_count": 0,
        "edited_files": [],
    }
    if state_file.exists():
        try:
            return {**default, **json.loads(state_file.read_text())}
        except Exception:
            pass
    return default


def save_state(state_dir, state):
    (state_dir / "state.json").write_text(json.dumps(state, indent=2))


# ---------------------------------------------------------------------------
# PostToolUse: post-edit  (track changes only, no background process)
# ---------------------------------------------------------------------------

def handle_post_edit(input_data):
    state_dir, _ = get_state_dir()
    state = load_state(state_dir)
    tool_input = input_data.get("tool_input", {})

    file_path = (
        tool_input.get("file_path")
        or tool_input.get("filePath")
        or ""
    )

    # Skip tracking when we couldn't extract a real file path
    if not file_path:
        save_state(state_dir, state)
        print(json.dumps({}))
        return

    state["edit_count"] = state.get("edit_count", 0) + 1
    edited = state.get("edited_files", [])
    if file_path not in edited:
        edited.append(file_path)
    state["edited_files"] = edited[-50:]

    # New edit after a completed review -> review is stale
    if state["review_status"] == "completed":
        state["review_stale"] = True

    context_msg = None

    # If review completed and findings not yet shown, inject them
    if state["review_status"] == "completed" and not state.get("findings_injected"):
        output = _get_review_output(state_dir)
        if output:
            context_msg = (
                "## CodeRabbit Review Results\n\n"
                f"{output}\n\n---\n"
                "Review the findings above. Address critical issues before committing."
            )
        state["findings_injected"] = True

    save_state(state_dir, state)

    if context_msg:
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": context_msg,
            }
        }))
    else:
        print(json.dumps({}))


# ---------------------------------------------------------------------------
# PostToolUse: mark-done  (after agent runs `coderabbit review`)
# ---------------------------------------------------------------------------

def handle_mark_done(input_data):
    """Called after Execute when the command was `coderabbit review`."""
    tool_input = input_data.get("tool_input", {})
    command = tool_input.get("command", "")

    # Only act on coderabbit review commands
    if not re.search(r"\bcoderabbit\s+review\b", command):
        print(json.dumps({}))
        return

    state_dir, _ = get_state_dir()
    state = load_state(state_dir)

    # Capture stdout if the hook system passes it; otherwise just mark done
    tool_output = input_data.get("tool_output", "")
    output_file = state_dir / "review-output.txt"
    if tool_output:
        output_file.write_text(
            tool_output if isinstance(tool_output, str) else json.dumps(tool_output)
        )

    state["review_status"] = "completed"
    state["review_stale"] = False
    state["findings_injected"] = False
    save_state(state_dir, state)

    output = _get_review_output(state_dir)
    ctx = ""
    if output:
        ctx = (
            "## CodeRabbit Review Completed\n\n"
            f"{output}\n\n---\n"
            "Address critical findings before committing. "
            "You may now run `git commit`."
        )

    if ctx:
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": ctx,
            }
        }))
    else:
        print(json.dumps({}))


# ---------------------------------------------------------------------------
# PreToolUse: pre-commit gate
# ---------------------------------------------------------------------------

def handle_pre_commit(input_data):
    tool_input = input_data.get("tool_input", {})
    command = tool_input.get("command", "")

    # Only gate git commit commands
    if not re.search(r"\bgit\s+commit\b", command):
        print(json.dumps({}))
        return

    state_dir, _ = get_state_dir()
    state = load_state(state_dir)

    # No tracked edits -> nothing to review, allow commit
    if state.get("edit_count", 0) == 0 and not state.get("edited_files"):
        print(json.dumps({}))
        return

    # Review completed and covers current changes -> ALLOW
    if state["review_status"] == "completed" and not state.get("review_stale"):
        output = _get_review_output(state_dir)
        ctx = ""
        if output and not state.get("findings_injected"):
            ctx = (
                "## CodeRabbit Review (Pre-Commit)\n\n"
                f"{output}\n\n"
                "Proceeding with commit. Findings are advisory."
            )

        # Reset state for next cycle
        state.update({
            "edit_count": 0,
            "edited_files": [],
            "review_status": "none",
            "review_stale": False,
            "findings_injected": False,
        })
        save_state(state_dir, state)

        if ctx:
            print(json.dumps({
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "additionalContext": ctx,
                }
            }))
        else:
            print(json.dumps({}))
        return

    # ---------- DENY ----------

    n_edits = state.get("edit_count", 0)
    n_files = len(state.get("edited_files", []))

    if state["review_status"] == "completed" and state.get("review_stale"):
        reason = (
            f"CodeRabbit review gate: {n_edits} new edits across {n_files} files since your last review.\n\n"
            "This is NOT a git hook error. Do NOT debug git hooks or git config.\n"
            "Simply run this exact command:\n\n"
            "  coderabbit review --prompt-only --type uncommitted\n\n"
            "Then retry your git commit."
        )
    else:
        reason = (
            f"CodeRabbit review gate: no review completed yet ({n_edits} edits, {n_files} files).\n\n"
            "This is NOT a git hook error. Do NOT debug git hooks or git config.\n"
            "Simply run this exact command:\n\n"
            "  coderabbit review --prompt-only --type uncommitted\n\n"
            "Then retry your git commit."
        )

    # Don't save state changes here (no side effects on deny)
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(2)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_review_output(state_dir):
    output_file = state_dir / "review-output.txt"
    if output_file.exists():
        return output_file.read_text().strip()
    return ""


def _fallback_parse(raw):
    """Extract essential fields via regex when JSON is malformed
    (e.g. tool_output contains unescaped quotes/newlines)."""
    data = {}

    m = re.search(r'"tool_name"\s*:\s*"([^"]*)"', raw)
    if m:
        data["tool_name"] = m.group(1)

    m = re.search(r'"command"\s*:\s*"((?:[^"\\]|\\.)*)"', raw)
    if m:
        data.setdefault("tool_input", {})["command"] = m.group(1)

    m = re.search(r'"file_path"\s*:\s*"((?:[^"\\]|\\.)*)"', raw)
    if m:
        data.setdefault("tool_input", {})["file_path"] = m.group(1)

    m = re.search(r'"filePath"\s*:\s*"((?:[^"\\]|\\.)*)"', raw)
    if m:
        data.setdefault("tool_input", {})["filePath"] = m.group(1)

    return data


# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------

def main():
    try:
        raw = sys.stdin.read()
        mode = sys.argv[1] if len(sys.argv) > 1 else "post-edit"
        try:
            input_data = json.loads(raw, strict=False)
        except json.JSONDecodeError:
            # tool_output may contain unescaped chars that break JSON.
            # Extract the fields we need via regex as fallback.
            input_data = _fallback_parse(raw)

        if mode == "post-edit":
            handle_post_edit(input_data)
        elif mode == "pre-commit":
            handle_pre_commit(input_data)
        elif mode == "mark-done":
            handle_mark_done(input_data)
        else:
            print(json.dumps({}))
    except Exception as e:
        print(json.dumps({}))
        print(f"CodeRabbit hook error (allowing): {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
