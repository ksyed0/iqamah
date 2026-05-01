#!/usr/bin/env bash
# bump_version.sh — Semantic version bump for the Iqamah Xcode project.
#
# Usage:
#   ./scripts/bump_version.sh [major|minor|patch]   # bump marketing version + build
#   ./scripts/bump_version.sh build                 # bump build number only
#   ./scripts/bump_version.sh set 2.1.0             # set an explicit version
#
# Xcode integration:
#   MARKETING_VERSION  (CFBundleShortVersionString) is written directly to
#   project.pbxproj — the only authoritative source for projects that use
#   GENERATE_INFOPLIST_FILE = YES (no on-disk Info.plist exists).
#
#   CURRENT_PROJECT_VERSION (CFBundleVersion / build number) is incremented
#   using `xcrun agvtool new-version`, which updates all build configurations
#   atomically and is the Apple-recommended approach.
#
# Outputs (for GitHub Actions):
#   Sets GITHUB_OUTPUT variables: new_version, new_build

set -euo pipefail

# ── Paths ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PBXPROJ="$PROJECT_ROOT/iqamah.xcodeproj/project.pbxproj"

cd "$PROJECT_ROOT"

# ── Helpers ───────────────────────────────────────────────────────────────
die()  { echo "❌  $*" >&2; exit 1; }
info() { echo "ℹ️   $*"; }
ok()   { echo "✅  $*"; }

github_output() {
  # Write key=value to GITHUB_OUTPUT when running in Actions; ignore otherwise
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "$1=$2" >> "$GITHUB_OUTPUT"
  fi
}

# ── Read current MARKETING_VERSION from pbxproj ───────────────────────────
# The project uses GENERATE_INFOPLIST_FILE = YES so there is no on-disk
# Info.plist; MARKETING_VERSION in pbxproj is the single source of truth.
read_marketing_version() {
  grep -m1 'MARKETING_VERSION' "$PBXPROJ" \
    | tr -d '[:space:]' \
    | sed 's/MARKETING_VERSION=//;s/;//'
}

# ── Write MARKETING_VERSION to all build configurations ───────────────────
write_marketing_version() {
  local new_ver="$1"
  # Replace every occurrence (covers Debug + Release configs)
  sed -i '' "s/MARKETING_VERSION = [0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/MARKETING_VERSION = $new_ver/g" "$PBXPROJ"
}

# ── Read current build number via agvtool ────────────────────────────────
read_build_number() {
  xcrun agvtool what-version -terse 2>/dev/null | tail -1 | tr -d '[:space:]'
}

# ── Bump build number via agvtool ────────────────────────────────────────
bump_build_number() {
  local next_build="$1"
  # Suppress the "Cannot find iqamah.xcodeproj/../YES" warning — it refers to
  # the auto-generated Info.plist which doesn't exist on disk; pbxproj is
  # updated correctly regardless.
  xcrun agvtool new-version -all "$next_build" 2>&1 | grep -v "Cannot find" || true
}

# ── Parse semver ─────────────────────────────────────────────────────────
parse_semver() {
  local ver="$1"
  # Normalise "1.0" → "1.0.0"
  local parts
  IFS='.' read -r -a parts <<< "$ver"
  MAJOR="${parts[0]:-0}"
  MINOR="${parts[1]:-0}"
  PATCH="${parts[2]:-0}"
}

# ── Main ──────────────────────────────────────────────────────────────────
BUMP_TYPE="${1:-patch}"
CUSTOM_VERSION="${2:-}"

CURRENT_VERSION="$(read_marketing_version)"
CURRENT_BUILD="$(read_build_number)"

[[ -n "$CURRENT_VERSION" ]] || die "Could not read MARKETING_VERSION from $PBXPROJ"
[[ -n "$CURRENT_BUILD"   ]] || die "Could not read CURRENT_PROJECT_VERSION via agvtool"

info "Current: v$CURRENT_VERSION (build $CURRENT_BUILD)"

# Determine new marketing version
if [[ "$BUMP_TYPE" == "build" ]]; then
  NEW_VERSION="$CURRENT_VERSION"
elif [[ "$BUMP_TYPE" == "set" ]]; then
  [[ -n "$CUSTOM_VERSION" ]] || die "Usage: $0 set <X.Y.Z>"
  NEW_VERSION="$CUSTOM_VERSION"
else
  parse_semver "$CURRENT_VERSION"
  case "$BUMP_TYPE" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
    *)     die "Unknown bump type '$BUMP_TYPE'. Use: major | minor | patch | build | set <X.Y.Z>" ;;
  esac
  NEW_VERSION="$MAJOR.$MINOR.$PATCH"
fi

NEW_BUILD=$((CURRENT_BUILD + 1))

# Apply changes
if [[ "$NEW_VERSION" != "$CURRENT_VERSION" ]]; then
  write_marketing_version "$NEW_VERSION"
fi
bump_build_number "$NEW_BUILD"

# Verify
VERIFIED_VERSION="$(read_marketing_version)"
VERIFIED_BUILD="$(read_build_number)"

[[ "$VERIFIED_VERSION" == "$NEW_VERSION" ]] \
  || die "Version write failed — pbxproj still shows $VERIFIED_VERSION"
[[ "$VERIFIED_BUILD" == "$NEW_BUILD" ]] \
  || die "Build number write failed — pbxproj still shows $VERIFIED_BUILD"

ok "Bumped to v$NEW_VERSION (build $NEW_BUILD)"

# Export for GitHub Actions
github_output "new_version" "$NEW_VERSION"
github_output "new_build"   "$NEW_BUILD"
github_output "prev_version" "$CURRENT_VERSION"
github_output "prev_build"   "$CURRENT_BUILD"
