#!/usr/bin/env bash
# Keepalive: keep this repo under GitHub's 60-day scheduled-workflow inactivity
# threshold, but only commit when actually necessary. GitHub disables scheduled
# workflows after 60 days with no repository activity -- and scheduled runs
# themselves do NOT count as activity -- which is what silenced the cve-alert
# daily/weekly digests.
#
# The workflow runs daily, but this script is a no-op until the most recent
# commit is older than KEEPALIVE_MAX_AGE_DAYS (default 50). Only then does it
# make a real, tracked file change, commit as the Actions bot, and push --
# resetting the inactivity clock with days of retry margin to spare, and
# without spamming the history with commits nothing needs.
#
# A real file change is used on purpose: empty commits are not reliably counted
# as repository activity.
#
# Safe to run locally; override the threshold with KEEPALIVE_MAX_AGE_DAYS.
#
# Usage:
#   ./scripts/keepalive.sh

set -euo pipefail

max_age_days="${KEEPALIVE_MAX_AGE_DAYS:-50}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
cd "$repo_root"

# Age of the most recent commit, in whole days. actions/checkout fetches only
# the tip by default, which is all this needs.
last_commit_epoch="$(git log -1 --format=%ct)"
now_epoch="$(date -u +%s)"
age_days=$(( (now_epoch - last_commit_epoch) / 86400 ))

if (( age_days < max_age_days )); then
    echo "keepalive: last commit ${age_days}d ago (< ${max_age_days}d); nothing to do"
    exit 0
fi

echo "keepalive: last commit ${age_days}d ago (>= ${max_age_days}d); bumping timestamp"
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
