#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')

# Snazzy color scheme (matching your p10k theme)
blue='57C7FF'
grey='242'
cyan='9AEDFE'

# Get git branch and status (skip optional locks to avoid blocking)
git_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null || echo "detached")

    # Check if there are any changes
    if ! git -C "$cwd" --no-optional-locks diff --quiet 2>/dev/null || \
       ! git -C "$cwd" --no-optional-locks diff --cached --quiet 2>/dev/null || \
       [ -n "$(git -C "$cwd" --no-optional-locks ls-files --others --exclude-standard 2>/dev/null)" ]; then
        dirty="*"
    else
        dirty=""
    fi

    # Format git info in grey (matching p10k vcs segment)
    git_info=$(printf "\033[38;5;${grey}m ${branch}${dirty}\033[0m")
fi

# Format directory in blue (matching p10k dir segment)
dir_info=$(printf "\033[38;2;87;199;255m%s\033[0m" "$cwd")

# Display: dir git_info
printf "%s%s" "$dir_info" "$git_info"
