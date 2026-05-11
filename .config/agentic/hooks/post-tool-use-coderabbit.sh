#!/usr/bin/env bash
# PostToolUse hook: Starts/checks background CodeRabbit review after code edits
# Matches: Write|Edit|MultiEdit

set -euo pipefail

input=$(cat)
if [[ -z "$input" ]]; then
	exit 0
fi

echo "$input" | python3 ~/.config/agentic/hooks/coderabbit-review.py post-edit
exit $?
