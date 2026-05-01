#!/usr/bin/env bash
# detect_bump_type.sh — Infer semver bump type from Conventional Commits.
#
# Usage:
#   ./scripts/detect_bump_type.sh              # compare against latest semver tag
#   ./scripts/detect_bump_type.sh v1.0.0       # compare against a specific tag
#   ./scripts/detect_bump_type.sh --build-only # always output "build" (develop branch mode)
#
# Outputs one of: major | minor | patch | build
# "build" means no marketing version change — only CURRENT_PROJECT_VERSION increments.
#
# Conventional Commits rules applied:
#   BREAKING CHANGE footer OR type!: suffix  →  major
#   feat:                                    →  minor
#   fix: | perf: | refactor:                 →  patch
#   chore: | docs: | ci: | test: | style:    →  build (no user-visible change)
#   anything else                            →  patch (safe default)

set -euo pipefail

# ── Args ──────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--build-only" ]]; then
  echo "build"
  exit 0
fi

SINCE_REF="${1:-}"

# ── Find the last semver tag if none provided ─────────────────────────────
if [[ -z "$SINCE_REF" ]]; then
  SINCE_REF=$(git tag -l "v[0-9]*" | sort -V | tail -1 2>/dev/null || true)
fi

# ── Get commit subjects (and bodies for BREAKING CHANGE footers) ──────────
if [[ -z "$SINCE_REF" ]]; then
  LOG=$(git log --pretty=format:"%s%n%b" 2>/dev/null)
else
  LOG=$(git log "${SINCE_REF}..HEAD" --pretty=format:"%s%n%b" 2>/dev/null || git log --pretty=format:"%s%n%b")
fi

if [[ -z "$LOG" ]]; then
  # No commits since last tag — only bump the build number
  echo "build"
  exit 0
fi

# ── Classify ──────────────────────────────────────────────────────────────

# Major: breaking change footer OR type! (exclamation suffix)
if echo "$LOG" | grep -qE '(^BREAKING[[:space:]]CHANGE:|^[a-zA-Z]+(\([^)]*\))?!:)'; then
  echo "major"
  exit 0
fi

# Minor: new feature
if echo "$LOG" | grep -qE '^feat(\([^)]*\))?:'; then
  echo "minor"
  exit 0
fi

# Patch: bug fix, perf, or meaningful refactor
if echo "$LOG" | grep -qE '^(fix|perf|refactor)(\([^)]*\))?:'; then
  echo "patch"
  exit 0
fi

# Build-only: housekeeping commits that don't affect end-users
if echo "$LOG" | grep -qE '^(chore|docs|ci|test|style|build)(\([^)]*\))?:'; then
  # Only if EVERY commit is housekeeping — mixed batches should still patch-bump
  NON_HOUSEKEEPING=$(echo "$LOG" | grep -vE '^(chore|docs|ci|test|style|build)(\([^)]*\))?:' \
    | grep -vE '^$' || true)
  if [[ -z "$NON_HOUSEKEEPING" ]]; then
    echo "build"
    exit 0
  fi
fi

# Default: patch (safe fallback for any unrecognised commit format)
echo "patch"
