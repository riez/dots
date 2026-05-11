#!/usr/bin/env python3
"""
SonarQube Analysis Integration Hook

Modes:
  post-edit:   PostToolUse after Edit/Write/MultiEdit - detects code file edits,
               checks MCP health and project config, injects context for agent
               to call mcp__sonarqube__issues.
  mark-done:   PostToolUse after Bash - captures SonarQube MCP response, stores
               issues in state, injects findings as context.
  pre-commit:  PreToolUse before Bash - gates git commit on code quality. Runs
               sonar-scanner locally on changed files. Blocks on CRITICAL/BLOCKER/MAJOR;
               warns on MINOR/INFO.

State tracked in /tmp/sonarqube-analysis-{project_hash}/
"""

import json
import sys
import os
import hashlib
import re
import subprocess
import time
from pathlib import Path

STATE_DIR_BASE = "/tmp/sonarqube-analysis"

FALLBACK_URL = "https://sonarqube-local.taila7050b.ts.net"

SKILL_MAP_PATH = Path.home() / ".config" / "agentic" / "hooks" / "skill-map.json"

FALLBACK_SKIP_EXTENSIONS = [
    ".md", ".mdx", ".txt", ".json", ".yaml", ".yml", ".toml",
    ".xml", ".html", ".css", ".scss", ".less", ".svg", ".png",
    ".jpg", ".jpeg", ".gif", ".ico", ".env", ".gitignore",
    ".lock", ".log", ".csv", ".ini", ".cfg",
]

BYPASS_PATTERNS = [
    r"skip\s+sonar(qube)?",
    r"no\s+sonar(qube)?\s+(needed|required|check|analysis)",
    r"sonar(qube)?\s+already\s+(checked|scanned|clean)",
    r"skip\s+quality\s+check",
]

BLOCKING_SEVERITIES = {"CRITICAL", "BLOCKER", "MAJOR"}
WARNING_SEVERITIES = {"MINOR", "INFO"}

DEBOUNCE_SECONDS = 10
HEALTH_CACHE_SECONDS = 60


# ---------------------------------------------------------------------------
# State helpers
# ---------------------------------------------------------------------------

def get_state_dir() -> tuple[Path, str]:
    project_dir = os.environ.get("FACTORY_PROJECT_DIR", os.getcwd())
    dir_hash = hashlib.md5(project_dir.encode()).hexdigest()[:12]
    state_dir = Path(f"{STATE_DIR_BASE}-{dir_hash}")
    state_dir.mkdir(parents=True, exist_ok=True)
    return state_dir, project_dir


def load_state(state_dir: Path) -> dict:
    state_file = state_dir / "state.json"
    default: dict = {
        "files": {},
        "pending_scans": [],
        "edits_since_scan": 0,
        "edited_files": [],
    }
    if state_file.exists():
        try:
            return {**default, **json.loads(state_file.read_text())}
        except Exception:
            pass
    return default


def save_state(state_dir: Path, state: dict) -> None:
    (state_dir / "state.json").write_text(json.dumps(state, indent=2))


def load_health(state_dir: Path) -> dict:
    health_file = state_dir / "health.json"
    if health_file.exists():
        try:
            return json.loads(health_file.read_text())
        except Exception:
            pass
    return {}


def save_health(state_dir: Path, health: dict) -> None:
    (state_dir / "health.json").write_text(json.dumps(health, indent=2))


# ---------------------------------------------------------------------------
# Config resolution
# ---------------------------------------------------------------------------

def get_skip_extensions() -> list[str]:
    """Load skip_extensions from skill-map.json, fall back to hardcoded list."""
    if SKILL_MAP_PATH.exists():
        try:
            data = json.loads(SKILL_MAP_PATH.read_text())
            exts = data.get("skip_extensions")
            if isinstance(exts, list) and exts:
                return exts
        except Exception:
            pass
    return FALLBACK_SKIP_EXTENSIONS


def is_code_file(file_path: str) -> bool:
    """Return True if file_path has an extension that is NOT in skip list."""
    ext = Path(file_path).suffix.lower()
    if not ext:
        return False
    return ext not in get_skip_extensions()


def resolve_sonarqube_url() -> str:
    """Resolve SonarQube server URL from env, properties, or fallback."""
    url = os.environ.get("SONARQUBE_URL")
    if url:
        return url.rstrip("/")

    props = _find_sonar_properties(os.environ.get("FACTORY_PROJECT_DIR", os.getcwd()))
    if props:
        url = _parse_property(props, "sonar.host.url")
        if url:
            return url.rstrip("/")

    return FALLBACK_URL


def resolve_sonarqube_token() -> str | None:
    """Resolve SonarQube token from env, then macOS Keychain."""
    token = os.environ.get("SONARQUBE_TOKEN")
    if token:
        return token

    try:
        result = subprocess.run(
            ["security", "find-generic-password", "-s", "sonarqube-analysis-token", "-w"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except Exception:
        pass

    return None


def _find_sonar_properties(start_dir: str) -> Path | None:
    """Walk up to 3 parent dirs looking for sonar-project.properties."""
    current = Path(start_dir).resolve()
    for _ in range(4):  # current + 3 parents
        candidate = current / "sonar-project.properties"
        if candidate.exists():
            return candidate
        parent = current.parent
        if parent == current:
            break
        current = parent
    return None


def _parse_property(props_file: Path, key: str) -> str | None:
    """Extract a property value from a Java .properties file."""
    try:
        for line in props_file.read_text().splitlines():
            line = line.strip()
            if line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            if k.strip() == key:
                return v.strip()
    except Exception:
        pass
    return None


def _get_project_key(project_dir: str) -> str | None:
    """Extract sonar.projectKey from sonar-project.properties."""
    props = _find_sonar_properties(project_dir)
    if props:
        return _parse_property(props, "sonar.projectKey")
    return None


# ---------------------------------------------------------------------------
# MCP health check
# ---------------------------------------------------------------------------

def check_mcp_health(state_dir: Path) -> bool:
    """Check SonarQube reachability. Caches result for HEALTH_CACHE_SECONDS."""
    health = load_health(state_dir)
    now = time.time()

    last_check = health.get("last_check", 0)
    if now - last_check < HEALTH_CACHE_SECONDS:
        return health.get("reachable", False)

    url = resolve_sonarqube_url()
    reachable = False
    try:
        result = subprocess.run(
            ["curl", "-sf", "-o", "/dev/null", "-w", "%{http_code}",
             f"{url}/api/system/status"],
            capture_output=True, text=True, timeout=10,
        )
        code = result.stdout.strip()
        reachable = code.startswith("2")
    except Exception:
        pass

    health["reachable"] = reachable
    health["last_check"] = now
    save_health(state_dir, health)
    return reachable


def _warn_once_if_unreachable(state_dir: Path) -> str | None:
    """Return a warning string if SonarQube is unreachable and not yet warned."""
    health = load_health(state_dir)
    if health.get("reachable", False):
        return None
    if health.get("warned", False):
        return None
    health["warned"] = True
    save_health(state_dir, health)
    url = resolve_sonarqube_url()
    return (
        f"[SonarQube] Server at {url} is unreachable. "
        "Quality analysis will use cached state only. "
        "Check VPN/network if this persists."
    )


def _offer_init_once(state_dir: Path, project_dir: str) -> str | None:
    """Offer to create sonar-project.properties once per session."""
    flag = state_dir / "init-offered.flag"
    if flag.exists():
        return None
    props = _find_sonar_properties(project_dir)
    if props:
        return None
    flag.touch()
    return (
        "[SonarQube] No sonar-project.properties found in project. "
        "Create one with at minimum:\n"
        "  sonar.projectKey=<your-project-key>\n"
        "  sonar.host.url=" + resolve_sonarqube_url() + "\n"
        "  sonar.sources=.\n"
        "This enables per-file issue tracking."
    )


# ---------------------------------------------------------------------------
# Bypass detection
# ---------------------------------------------------------------------------

def _check_bypass(input_data: dict) -> bool:
    """Check if the user has requested to bypass SonarQube analysis."""
    transcript = input_data.get("transcript", "")
    if isinstance(transcript, str):
        text = transcript[-5000:]
    else:
        text = ""

    for pattern in BYPASS_PATTERNS:
        if re.search(pattern, text, re.IGNORECASE):
            return True
    return False


# ---------------------------------------------------------------------------
# PostToolUse: post-edit
# ---------------------------------------------------------------------------

def handle_post_edit(input_data: dict) -> None:
    """Track code file edits and inject SonarQube scan context."""
    state_dir, project_dir = get_state_dir()
    state = load_state(state_dir)
    tool_input = input_data.get("tool_input", {})

    file_path = tool_input.get("file_path") or tool_input.get("filePath") or ""

    if not file_path:
        print(json.dumps({}))
        return

    if not is_code_file(file_path):
        print(json.dumps({}))
        return

    if _check_bypass(input_data):
        print(json.dumps({}))
        return

    # Debounce: skip if same file scanned recently
    now = time.time()
    file_state = state.get("files", {}).get(file_path, {})
    last_scan = file_state.get("last_scan", 0)
    if now - last_scan < DEBOUNCE_SECONDS:
        print(json.dumps({}))
        return

    # Track edit
    state["edits_since_scan"] = state.get("edits_since_scan", 0) + 1
    edited = state.get("edited_files", [])
    if file_path not in edited:
        edited.append(file_path)
    state["edited_files"] = edited[-50:]

    # MCP health check (cached)
    reachable = check_mcp_health(state_dir)

    context_parts: list[str] = []

    # Warn once if unreachable
    warning = _warn_once_if_unreachable(state_dir)
    if warning:
        context_parts.append(warning)

    # Offer init once
    init_msg = _offer_init_once(state_dir, project_dir)
    if init_msg:
        context_parts.append(init_msg)

    # Add to pending scans
    pending = state.get("pending_scans", [])
    if file_path not in pending:
        pending.append(file_path)
    state["pending_scans"] = pending

    save_state(state_dir, state)

    if reachable:
        project_key = _get_project_key(project_dir)
        if project_key:
            try:
                rel_path = str(Path(file_path).resolve().relative_to(Path(project_dir).resolve()))
            except ValueError:
                rel_path = Path(file_path).name

            context_parts.append(
                f"You edited {file_path}. "
                f"Call mcp__sonarqube__issues with component: {project_key}:{rel_path}"
            )
        else:
            context_parts.append(
                f"You edited {file_path}. "
                "No sonar.projectKey configured — cannot request issue scan."
            )

    if context_parts:
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": "\n\n".join(context_parts),
            }
        }))
    else:
        print(json.dumps({}))


# ---------------------------------------------------------------------------
# PostToolUse: mark-done (capture SonarQube MCP response)
# ---------------------------------------------------------------------------

def handle_mark_done(input_data: dict) -> None:
    """Capture and process SonarQube MCP response from tool output."""
    tool_input = input_data.get("tool_input", {})
    tool_output = input_data.get("tool_output", "")
    command = tool_input.get("command", "")
    tool_name = input_data.get("tool_name", "")

    # Check if this relates to sonarqube
    combined = f"{command} {tool_name} {tool_output if isinstance(tool_output, str) else json.dumps(tool_output)}"
    if not re.search(r"sonar(qube)?", combined, re.IGNORECASE):
        print(json.dumps({}))
        return

    state_dir, project_dir = get_state_dir()
    state = load_state(state_dir)

    # Save raw output
    output_text = tool_output if isinstance(tool_output, str) else json.dumps(tool_output, indent=2)
    (state_dir / "scan-output.txt").write_text(output_text)

    # Parse issues from MCP response
    issues = _parse_mcp_issues(tool_output)

    # Group issues by file and update state
    files_state = state.get("files", {})
    seen_files: set[str] = set()

    for issue in issues:
        component = issue.get("component", "")
        # Extract relative path from component (format: projectKey:path/to/file)
        file_path = component.split(":", 1)[-1] if ":" in component else component
        if not file_path:
            continue
        seen_files.add(file_path)
        files_state.setdefault(file_path, {"issues": [], "last_scan": 0})
        files_state[file_path]["issues"] = [
            i for i in files_state[file_path].get("issues", [])
            if i.get("key") != issue.get("key")
        ]
        files_state[file_path]["issues"].append(issue)
        files_state[file_path]["last_scan"] = time.time()

    # Clear files with no issues that were scanned
    pending = state.get("pending_scans", [])
    for fp in list(pending):
        rel = fp
        try:
            rel = str(Path(fp).resolve().relative_to(Path(project_dir).resolve()))
        except (ValueError, Exception):
            pass
        if rel in seen_files or fp in seen_files:
            pending.remove(fp)
            if rel in files_state and not files_state[rel].get("issues"):
                del files_state[rel]

    state["files"] = files_state
    state["pending_scans"] = pending
    save_state(state_dir, state)

    # Build context message
    blocking = []
    minor = []
    for issue in issues:
        sev = issue.get("severity", "").upper()
        msg = _format_issue(issue)
        if sev in BLOCKING_SEVERITIES:
            blocking.append(msg)
        else:
            minor.append(msg)

    context_parts: list[str] = []
    if blocking:
        context_parts.append(
            "## SonarQube: Blocking Issues (fix before committing)\n\n"
            + "\n".join(blocking)
        )
    if minor:
        context_parts.append(
            "## SonarQube: Minor Issues (consider fixing)\n\n"
            + "\n".join(minor)
        )
    if not blocking and not minor:
        context_parts.append(
            "## SonarQube: Looks Good\n\n"
            "No issues found for scanned files. You may proceed with committing."
        )

    state["edits_since_scan"] = 0
    save_state(state_dir, state)

    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": "\n\n".join(context_parts),
        }
    }))


def _parse_mcp_issues(tool_output: object) -> list[dict]:
    """Parse issues from MCP response (JSON dict, string, or list)."""
    data = tool_output
    if isinstance(data, str):
        try:
            data = json.loads(data)
        except (json.JSONDecodeError, ValueError):
            return []

    if isinstance(data, dict):
        # Standard SonarQube API response: {"issues": [...]}
        if "issues" in data:
            return data["issues"] if isinstance(data["issues"], list) else []
        # Single issue wrapped in a dict
        if "key" in data or "rule" in data:
            return [data]
        # Nested content field (MCP wrapping)
        content = data.get("content", data.get("result", data.get("data")))
        if content:
            return _parse_mcp_issues(content)
    elif isinstance(data, list):
        return data

    return []


def _format_issue(issue: dict) -> str:
    """Format a single issue for display."""
    sev = issue.get("severity", "UNKNOWN")
    rule = issue.get("rule", "")
    msg = issue.get("message", "")
    component = issue.get("component", "")
    line = issue.get("line", issue.get("textRange", {}).get("startLine", "?"))
    file_part = component.split(":", 1)[-1] if ":" in component else component
    return f"- [{sev}] {file_part}:{line} — {msg} ({rule})"


# ---------------------------------------------------------------------------
# PreToolUse: pre-commit gate
# ---------------------------------------------------------------------------

def handle_pre_commit(input_data: dict) -> None:
    """Gate git commit on SonarQube code quality."""
    tool_input = input_data.get("tool_input", {})
    command = tool_input.get("command", "")

    # Only gate git commit commands
    if not re.search(r"\bgit\s+commit\b", command):
        print(json.dumps({}))
        return

    if _check_bypass(input_data):
        print(json.dumps({}))
        return

    state_dir, project_dir = get_state_dir()

    # Check sonar-project.properties exists; skip gating if not configured
    props = _find_sonar_properties(project_dir)
    if not props:
        print(json.dumps({}))
        return

    project_key = _parse_property(props, "sonar.projectKey")

    # Get changed code files
    changed_files = _get_changed_code_files(project_dir)
    if not changed_files:
        print(json.dumps({}))
        return

    # Try sonar-scanner locally first
    scanner_issues = _run_sonar_scanner(project_dir, props)

    if scanner_issues is not None:
        issues = scanner_issues
    else:
        # Fall back to state-based issues
        state = load_state(state_dir)
        issues = []
        files_state = state.get("files", {})
        for fp in changed_files:
            rel = fp
            try:
                rel = str(Path(fp).resolve().relative_to(Path(project_dir).resolve()))
            except (ValueError, Exception):
                pass
            file_issues = files_state.get(rel, {}).get("issues", [])
            if not file_issues:
                file_issues = files_state.get(fp, {}).get("issues", [])
            issues.extend(file_issues)

    blocking = []
    warnings = []
    for issue in issues:
        sev = issue.get("severity", "").upper()
        msg = _format_issue(issue)
        if sev in BLOCKING_SEVERITIES:
            blocking.append(msg)
        elif sev in WARNING_SEVERITIES:
            warnings.append(msg)

    # Blocking issues: deny commit
    if blocking:
        reason = (
            f"SonarQube quality gate: {len(blocking)} blocking issue(s) found.\n\n"
            + "\n".join(blocking)
            + "\n\nFix these issues before committing. "
            "Use 'skip sonarqube' in conversation to bypass."
        )
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        }))
        sys.exit(2)

    # Warnings only: allow but inform
    if warnings:
        ctx = (
            "## SonarQube: Minor Issues\n\n"
            + "\n".join(warnings)
            + "\n\nThese are non-blocking. Consider fixing them."
        )
        # Clear state for committed files
        _clear_committed_files(state_dir, project_dir, changed_files)
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "additionalContext": ctx,
            }
        }))
        return

    # Clean commit
    _clear_committed_files(state_dir, project_dir, changed_files)
    print(json.dumps({}))


def _get_changed_code_files(project_dir: str) -> list[str]:
    """Get changed code files from git (staged + unstaged)."""
    files: set[str] = set()
    for diff_cmd in [
        ["git", "diff", "--cached", "--name-only"],
        ["git", "diff", "--name-only"],
    ]:
        try:
            result = subprocess.run(
                diff_cmd, capture_output=True, text=True,
                cwd=project_dir, timeout=10,
            )
            if result.returncode == 0:
                for line in result.stdout.strip().splitlines():
                    fp = line.strip()
                    if fp and is_code_file(fp):
                        files.add(fp)
        except Exception:
            pass
    return sorted(files)


def _run_sonar_scanner(project_dir: str, props: Path) -> list[dict] | None:
    """Try running sonar-scanner in preview mode. Return issues or None if unavailable."""
    # Check if sonar-scanner is installed
    try:
        result = subprocess.run(
            ["which", "sonar-scanner"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode != 0:
            return None
    except Exception:
        return None

    # Run in preview/analysis mode
    token = resolve_sonarqube_token()
    url = resolve_sonarqube_url()

    cmd = [
        "sonar-scanner",
        f"-Dsonar.host.url={url}",
        "-Dsonar.analysis.mode=preview",
        f"-Dsonar.projectBaseDir={project_dir}",
        f"-Dsonar.report.export.path=sonar-report.json",
    ]
    try:
        env = os.environ.copy()
        if token:
            env["SONAR_TOKEN"] = token
        result = subprocess.run(
            cmd, capture_output=True, text=True,
            cwd=project_dir, timeout=120, env=env,
        )
        # Try to parse the report
        report_path = Path(project_dir) / ".sonar" / "sonar-report.json"
        if report_path.exists():
            report = json.loads(report_path.read_text())
            return report.get("issues", [])
    except Exception:
        pass

    return None


def _clear_committed_files(state_dir: Path, project_dir: str, changed_files: list[str]) -> None:
    """Clear state for files that are being committed."""
    state = load_state(state_dir)
    files_state = state.get("files", {})

    for fp in changed_files:
        rel = fp
        try:
            rel = str(Path(fp).resolve().relative_to(Path(project_dir).resolve()))
        except (ValueError, Exception):
            pass
        files_state.pop(rel, None)
        files_state.pop(fp, None)

    state["files"] = files_state
    state["edits_since_scan"] = 0
    state["edited_files"] = [
        f for f in state.get("edited_files", []) if f not in changed_files
    ]
    state["pending_scans"] = [
        f for f in state.get("pending_scans", []) if f not in changed_files
    ]
    save_state(state_dir, state)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _fallback_parse(raw: str) -> dict:
    """Extract essential fields via regex when JSON is malformed."""
    data: dict = {}

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

    # Try to extract tool_output for mark-done
    m = re.search(r'"tool_output"\s*:\s*"((?:[^"\\]|\\.)*)"', raw)
    if m:
        data["tool_output"] = m.group(1)

    return data


# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------

def main() -> None:
    try:
        raw = sys.stdin.read()
        mode = sys.argv[1] if len(sys.argv) > 1 else "post-edit"
        try:
            input_data = json.loads(raw, strict=False)
        except json.JSONDecodeError:
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
        print(f"SonarQube hook error (allowing): {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
