#!/usr/bin/env bash
# PostToolUse hook: Marks CodeRabbit review as completed after agent runs it
# Matches: Execute

set -euo pipefail

input=$(cat)
if [[ -z "$input" ]]; then
	exit 0
fi

echo "$input" | python3 ~/.config/agentic/hooks/coderabbit-review.py mark-done
exit $?
