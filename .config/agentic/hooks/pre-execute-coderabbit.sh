#!/usr/bin/env bash
# PreToolUse hook: Gates git commit on completed CodeRabbit review
# Matches: Execute

set -euo pipefail

input=$(cat)
if [[ -z "$input" ]]; then
	exit 0
fi

echo "$input" | python3 ~/.config/agentic/hooks/coderabbit-review.py pre-commit
exit $?
