#!/usr/bin/env python3
"""
PreToolUse Hook - Enforces discipline before code changes.

Two distinct flows:

1. BUG-FIXING: When problem keywords (bug, error, fix, broken) are detected,
   requires root cause analysis before allowing edits.

2. REFACTORING: When refactoring keywords (refactor, restructure, improve,
   clean up) are detected, requires before/after state definition and an
   approach description before allowing edits.

Exit codes:
- 0: Allow the operation
- 2: Block the operation (returns deny with reason)
"""

import json
import sys
import re
from pathlib import Path

# ============================================================================
# Configuration
# ============================================================================

# Tools that require root cause analysis when fixing issues
PROTECTED_TOOLS = {"Edit", "Write", "MultiEdit"}

# Keywords that indicate this is a problem-fixing session (triggers the check)
PROBLEM_KEYWORDS = [
    r"\bbug\b",
    r"\berror\b",
    r"\bfix\b",
    r"\bbroken\b",
    r"\bfail(ing|ed|s)?\b",
    r"\bcrash(ing|ed|es)?\b",
    r"\bissue\b",
    r"\bproblem\b",
    r"\bperformance\b",
    r"\bslow\b",
    r"\btimeout\b",
    r"\bmemory\s*(leak)?\b",
    r"\bnot\s+work(ing)?\b",
    r"\bdoesn'?t\s+work\b",
    r"\bwon'?t\s+work\b",
    r"\bregression\b",
    r"\bunexpected\b",
    r"\bwrong\b",
    r"\bincorrect\b",
    r"\bdebug(ging)?\b",
]

# Patterns that indicate root cause analysis was performed
ANALYSIS_PATTERNS = [
    # Explicit root cause language
    r"root\s+cause",
    r"cause[sd]?\s+(by|is|was|are)",
    r"the\s+(actual\s+)?problem\s+is",
    r"the\s+issue\s+(is|was)\s+(that|because)",
    r"this\s+(happens|occurs|fails)\s+because",
    r"identified.*cause",
    r"diagnosed",
    r"analysis\s+(shows?|reveals?|indicates?)",
    # Understanding language
    r"after\s+(investigating|examining|analyzing)",
    r"upon\s+(investigation|examination|analysis)",
    r"investigation\s+(shows?|reveals?)",
    r"found\s+(that\s+)?the\s+(root\s+)?cause",
    r"traced\s+(back\s+)?to",
    r"the\s+underlying\s+(issue|problem|cause)",
    # Technical diagnosis
    r"stack\s+trace\s+(shows?|indicates?)",
    r"logs?\s+(show|indicate|reveal)",
    r"profil(er|ing)\s+(shows?|reveals?)",
    r"debug(ger|ging)\s+(shows?|reveals?)",
    r"(the\s+)?error\s+(originates?|comes?)\s+from",
    r"bottleneck\s+(is|was|at)",
    # Hypothesis testing
    r"hypothesis",
    r"verified\s+(that|the)",
    r"confirmed\s+(that|the)",
    r"reproduced\s+(the\s+)?(issue|bug|error|problem)",
    # Tool usage indicating analysis
    r"@superpowers:code-explorer.*trac",  # tracing with explorer
    r"mcp_pal_debug",
    r"mcp_pal_thinkdeep",
    r"systematic.*debug",
]

# Patterns that indicate workaround/band-aid (should warn)
WORKAROUND_PATTERNS = [
    r"workaround",
    r"band[\s-]?aid",
    r"quick\s+fix",
    r"temporary\s+(fix|solution)",
    r"hack\b",
    r"for\s+now",
    r"just\s+(add|wrap|catch)",
    r"suppress\s+(the\s+)?(error|warning|exception)",
    r"ignore\s+(the\s+)?(error|warning|exception)",
    r"try[\s/]catch.*empty",
    r"swallow.*exception",
    r"hide\s+(the\s+)?(error|issue)",
]

# Bypass patterns for bug-fixing
BYPASS_PATTERNS = [
    r"skip\s+(root\s+cause|analysis|diagnosis)",
    r"already\s+(know|understand|diagnosed)",
    r"obvious\s+(fix|issue|problem)",
    r"simple\s+typo",
    r"known\s+issue",
]

# ============================================================================
# Refactoring Flow Configuration
# ============================================================================

# Keywords that indicate a refactoring session (distinct from bug-fixing)
REFACTOR_KEYWORDS = [
    r"\brefactor(ing|ed|s)?\b",
    r"\brestructur(e|ing|ed)\b",
    r"\breorganiz(e|ing|ed)\b",
    r"\bclean\s*(up|ing)\b",
    r"\bsimplif(y|ying|ied)\b",
    r"\bmoderniz(e|ing|ed)\b",
    r"\bextract\s+(method|function|class|component|module)\b",
    r"\binline\s+(method|function|variable)\b",
    r"\brename\s+(method|function|class|variable)\b",
    r"\bmove\s+(method|function|class|to)\b",
    r"\bdecompos(e|ing|ed)\b",
    r"\bconsolidat(e|ing|ed)\b",
    r"\breduc(e|ing)\s+(complexity|duplication)\b",
    r"\btechnical\s+debt\b",
    r"\bcode\s+smell\b",
    r"\bimprove\s+(code|structure|readability|maintainability|design)\b",
    r"\bDRY\s+(up|out|principle)\b",
]

# Patterns that indicate before-state was defined
BEFORE_STATE_PATTERNS = [
    r"current(ly)?\s+(\w+\s+)?(state|behavior|implementation|code|structure|design)",
    r"before\s+(the\s+)?(refactor|change|restructur)",
    r"existing\s+(\w+\s+)?(behavior|implementation|code|structure|pattern)",
    r"(right|as\s+it\s+is)\s+now",
    r"the\s+current\s+(approach|design|architecture|code|structure)",
    r"what\s+(we|it)\s+(have|has|look)",
    r"as[\s-]is",
    r"today('s|,)?\s+(the|this|it)",
    r"present\s+(state|implementation|structure)",
    r"status\s+quo",
    r"currently[,]?\s+(the|this|it|we|our)",
]

# Patterns that indicate after-state was defined
AFTER_STATE_PATTERNS = [
    r"(after|expected)\s+(the\s+)?(refactor|change|restructur)",
    r"should\s+(become|look|be\s+restructured|be\s+organized)",
    r"target\s+(state|structure|design|architecture)",
    r"end\s+(state|result|goal)",
    r"the\s+(goal|objective|outcome)\s+is",
    r"(will|would)\s+(look|be(come)?|result)",
    r"to[\s-]be",
    r"desired\s+(state|outcome|structure|behavior)",
    r"expected\s+(outcome|result|behavior|state)",
    r"want\s+(it|this|the\s+code)\s+to",
    r"intended\s+(behavior|structure|design)",
]

# Patterns that indicate a refactoring approach was described
APPROACH_PATTERNS = [
    r"(approach|strategy|plan)\s+(is|will\s+be|:)",
    r"step[s]?\s*(\d|:)",
    r"(first|then|next|finally)\s*(,|we|i)",
    r"the\s+(plan|approach|strategy)\s+is",
    r"(will|going\s+to)\s+(extract|inline|rename|move|split|merge|decompose)",
    r"by\s+(extracting|inlining|renaming|moving|splitting|merging)",
    r"phase\s*\d",
    r"refactoring\s+(approach|plan|strategy|steps)",
]

# Bypass patterns for refactoring
REFACTOR_BYPASS_PATTERNS = [
    r"skip\s+(before.after|refactor\s+(analysis|check|gate))",
    r"quick\s+refactor",
    r"minor\s+refactor",
    r"trivial\s+rename",
    r"simple\s+extract",
    r"obvious\s+refactor",
]

# File extensions for code files
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
}


def is_code_file(file_path: str) -> bool:
    """Check if the file is a code file."""
    path = Path(file_path)
    return path.suffix.lower() in CODE_EXTENSIONS


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


def is_problem_fixing_session(transcript_text: str) -> tuple[bool, list[str]]:
    """
    Check if this session involves fixing a problem.

    Returns (is_fixing_problem, matched_keywords)
    """
    matched = []
    for pattern in PROBLEM_KEYWORDS:
        if re.search(pattern, transcript_text, re.IGNORECASE):
            # Extract the matched word
            match = re.search(pattern, transcript_text, re.IGNORECASE)
            if match:
                matched.append(match.group())

    return len(matched) > 0, matched


def check_root_cause_analysis(transcript_text: str) -> tuple[bool, str]:
    """
    Check if root cause analysis was performed.

    Returns (analysis_done, evidence)
    """
    for pattern in ANALYSIS_PATTERNS:
        match = re.search(pattern, transcript_text, re.IGNORECASE)
        if match:
            return True, f"Found analysis: '{match.group()}'"

    return False, "No root cause analysis found in transcript"


def check_workaround_language(transcript_text: str) -> tuple[bool, str]:
    """
    Check if workaround language is present (warning sign).

    Returns (has_workaround_language, matched)
    """
    for pattern in WORKAROUND_PATTERNS:
        match = re.search(pattern, transcript_text, re.IGNORECASE)
        if match:
            return True, match.group()

    return False, ""


def check_bypass(transcript_text: str) -> tuple[bool, str]:
    """Check if user explicitly bypassed root cause analysis."""
    for pattern in BYPASS_PATTERNS:
        match = re.search(pattern, transcript_text, re.IGNORECASE)
        if match:
            return True, f"User bypass: '{match.group()}'"

    return False, ""


def is_refactoring_session(transcript_text: str) -> tuple[bool, list[str]]:
    """
    Check if this session involves refactoring.
    Refactoring takes priority over bug-fixing when both keywords match.

    Returns (is_refactoring, matched_keywords)
    """
    matched = []
    for pattern in REFACTOR_KEYWORDS:
        match = re.search(pattern, transcript_text, re.IGNORECASE)
        if match:
            matched.append(match.group())

    return len(matched) > 0, matched


def check_before_state(transcript_text: str) -> tuple[bool, str]:
    """Check if the current/before state was defined."""
    for pattern in BEFORE_STATE_PATTERNS:
        match = re.search(pattern, transcript_text, re.IGNORECASE)
        if match:
            return True, f"before-state: '{match.group()}'"
    return False, ""


def check_after_state(transcript_text: str) -> tuple[bool, str]:
    """Check if the expected/after state was defined."""
    for pattern in AFTER_STATE_PATTERNS:
        match = re.search(pattern, transcript_text, re.IGNORECASE)
        if match:
            return True, f"after-state: '{match.group()}'"
    return False, ""


def check_approach(transcript_text: str) -> tuple[bool, str]:
    """Check if the refactoring approach was described."""
    for pattern in APPROACH_PATTERNS:
        match = re.search(pattern, transcript_text, re.IGNORECASE)
        if match:
            return True, f"approach: '{match.group()}'"
    return False, ""


def check_refactor_bypass(transcript_text: str) -> tuple[bool, str]:
    """Check if user explicitly bypassed refactoring gate."""
    for pattern in REFACTOR_BYPASS_PATTERNS:
        match = re.search(pattern, transcript_text, re.IGNORECASE)
        if match:
            return True, f"User bypass: '{match.group()}'"
    return False, ""


def handle_refactoring_flow(transcript_text: str, refactor_keywords: list[str]):
    """Gate for refactoring sessions: requires before/after definition."""
    keywords_str = ", ".join(set(refactor_keywords[:5]))

    # Check bypass
    bypassed, bypass_reason = check_refactor_bypass(transcript_text)
    if bypassed:
        print(json.dumps({}))
        print(f"⚠️ Refactor gate bypass: {bypass_reason}", file=sys.stderr)
        return

    # Check all three requirements
    has_before, before_evidence = check_before_state(transcript_text)
    has_after, after_evidence = check_after_state(transcript_text)
    has_approach, approach_evidence = check_approach(transcript_text)

    missing = []
    if not has_before:
        missing.append("current state (before)")
    if not has_after:
        missing.append("expected state (after)")
    if not has_approach:
        missing.append("refactoring approach")

    if not missing:
        # All defined - allow
        evidence = ", ".join(filter(None, [before_evidence, after_evidence, approach_evidence]))
        print(json.dumps({}))
        print(f"✓ Refactoring flow defined: {evidence}", file=sys.stderr)
        return

    if len(missing) < 3:
        # Partially defined - allow with warning
        defined = ", ".join(filter(None, [before_evidence, after_evidence, approach_evidence]))
        print(json.dumps({}))
        print(
            f"⚠️ Refactoring partially defined (missing: {', '.join(missing)}). "
            f"Defined: {defined}",
            file=sys.stderr,
        )
        return

    # Nothing defined - BLOCK
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": (
                f"🛑 BLOCKED: Define before/after states before refactoring. "
                f"See /mandatory-workflow skill for full procedure."
            ),
        }
    }

    print(json.dumps(output))
    print(
        f"🛑 BLOCKED: Refactoring session ({keywords_str}) without before/after definition",
        file=sys.stderr,
    )
    sys.exit(2)


def handle_bugfix_flow(transcript_text: str, problem_keywords: list[str]):
    """Gate for bug-fixing sessions: requires root cause analysis."""
    keywords_str = ", ".join(set(problem_keywords[:5]))

    # Check for bypass
    bypassed, bypass_reason = check_bypass(transcript_text)
    if bypassed:
        print(json.dumps({}))
        print(f"⚠️ Root cause bypass: {bypass_reason}", file=sys.stderr)
        return

    # Check if analysis was done
    analyzed, analysis_evidence = check_root_cause_analysis(transcript_text)

    # Check for workaround language
    has_workaround, workaround_term = check_workaround_language(transcript_text)

    if analyzed:
        if has_workaround:
            print(json.dumps({}))
            print(
                f"⚠️ Analysis done but workaround language detected: '{workaround_term}'",
                file=sys.stderr,
            )
            print(
                "   Consider: Is this a proper fix or a band-aid?", file=sys.stderr
            )
        else:
            print(json.dumps({}))
            print(
                f"✓ Root cause analysis performed: {analysis_evidence}",
                file=sys.stderr,
            )
        return

    # No analysis found - BLOCK
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": (
                f"🛑 BLOCKED: Root cause required before fixing. "
                f"See /mandatory-workflow skill for full procedure."
            ),
        }
    }

    print(json.dumps(output))
    print(
        f"🛑 BLOCKED: Problem-fixing session ({keywords_str}) without root cause analysis",
        file=sys.stderr,
    )
    sys.exit(2)


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
                "⚠️ No transcript path provided, root cause check skipped",
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
            return

        # Read transcript
        entries = read_transcript(transcript_path)
        transcript_text = json.dumps(entries).lower()

        # Determine session type: refactoring takes priority over bug-fixing
        is_refactoring, refactor_keywords = is_refactoring_session(transcript_text)
        is_fixing, problem_keywords = is_problem_fixing_session(transcript_text)

        if is_refactoring:
            # ---- REFACTORING FLOW ----
            handle_refactoring_flow(transcript_text, refactor_keywords)
        elif is_fixing:
            # ---- BUG-FIXING FLOW ----
            handle_bugfix_flow(transcript_text, problem_keywords)
        else:
            # Neither flow - allow
            print(json.dumps({}))
            print(
                "✓ Not a problem-fixing or refactoring session, checks skipped",
                file=sys.stderr,
            )

    except Exception as e:
        print(json.dumps({}))
        print(f"⚠️ Hook error (allowing): {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
