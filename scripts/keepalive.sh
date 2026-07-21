#!/usr/bin/env bash
# Keepalive: bump a timestamp file and push it so this repo never goes 60 days
# without a commit. GitHub auto-disables scheduled workflows after 60 days of
# repository inactivity -- and scheduled runs themselves do NOT count as
# activity -- which is what silenced the cve-alert daily/weekly digests.
#
# A real file change is used on purpose: empty commits are not reliably counted
# as repository activity.
#
# Safe to run locally; it commits and pushes a one-line timestamp change. Push
# is skipped automatically when there is nothing new to commit.
#
# Usage:
#   ./scripts/keepalive.sh

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
cd "$repo_root"

date -u +%Y-%m-%dT%H:%M:%SZ > .keepalive
git add .keepalive

if git diff --cached --quiet; then
    echo "keepalive: nothing to commit"
    exit 0
fi

# Commit as the Actions bot without persisting identity into repo config.
git \
    -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit -m "keepalive: reset 60-day inactivity clock"
git push
