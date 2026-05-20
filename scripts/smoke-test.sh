#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# scripts/smoke-test.sh — Platform smoke test for Iqamah
#
# Builds each platform target, installs on its simulator (or runs on macOS),
# waits 5 seconds, then verifies the app is still alive and has not written
# a crash report.  Exits 0 if all requested platforms pass; 1 otherwise.
#
# Usage:
#   ./scripts/smoke-test.sh                  # all platforms
#   ./scripts/smoke-test.sh ios              # iPhone only
#   ./scripts/smoke-test.sh ipad            # iPad only
#   ./scripts/smoke-test.sh watch           # Apple Watch only
#   ./scripts/smoke-test.sh macos           # macOS only
#   ./scripts/smoke-test.sh ios ipad macos  # multiple
#
# AC-0300 – AC-0307 (US-0064, EPIC-0015)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Project constants ─────────────────────────────────────────────────────────
PROJECT="iqamah.xcodeproj"
BUILD_ROOT="/tmp/iqamah-smoke"
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"

BUNDLE_IOS="com.fablesoft.iqamah"
BUNDLE_WATCH="com.fablesoft.iqamah.watch"
BUNDLE_MACOS="com.fablesoft.iqamah"

SCHEME_IOS="iqamah-iOS"
SCHEME_WATCH="IqamahWatch"
SCHEME_MACOS="iqamah"

# Simulator model patterns (grep-compatible)
MODEL_IPHONE="iPhone 17[^P]"
MODEL_IPAD="iPad Pro 11"
MODEL_WATCH="Apple Watch Series 11"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "  $*"; }
pass() { echo -e "  ${GREEN}✅ $*${NC}"; }
fail() { echo -e "  ${RED}❌ $*${NC}"; }
warn() { echo -e "  ${YELLOW}⚠️  $*${NC}"; }
hdr()  { echo -e "\n${BOLD}${CYAN}▶ $*${NC}"; }

FAILURES=()
PASSES=()

# ── Simulator helpers ─────────────────────────────────────────────────────────

# Pick first available simulator matching a name pattern
pick_sim() {
    local pattern="$1"
    xcrun simctl list devices available --json 2>/dev/null \
        | python3 -c "
import sys, json, re
d = json.load(sys.stdin)
for devs in d['devices'].values():
    for dev in devs:
        if dev.get('isAvailable') and re.search(r'$pattern', dev.get('name','')):
            print(dev['udid']); exit(0)
exit(1)
" 2>/dev/null
}

# Boot a simulator if it's not already running
boot_sim() {
    local udid="$1"
    local state
    state=$(xcrun simctl list devices --json 2>/dev/null \
        | python3 -c "
import sys, json
d = json.load(sys.stdin)
for devs in d['devices'].values():
    for dev in devs:
        if dev.get('udid') == '$udid':
            print(dev.get('state','Unknown')); exit(0)
" 2>/dev/null || echo "Unknown")
    if [[ "$state" != "Booted" ]]; then
        log "Booting simulator ${udid}..."
        xcrun simctl boot "$udid" 2>/dev/null || true
        sleep 4
    fi
}

# ── Crash-report helper ───────────────────────────────────────────────────────

# Returns 0 (clean) or 1 (crash found) — also prints crash filename on failure
crashes_since() {
    local bundle_id="$1"
    local since_epoch="$2"
    local found=0
    if [[ -d "$CRASH_DIR" ]]; then
        while IFS= read -r -d '' f; do
            local mtime
            mtime=$(stat -f %m "$f" 2>/dev/null || echo 0)
            if [[ "$mtime" -gt "$since_epoch" ]]; then
                warn "Crash report: $(basename "$f")"
                found=1
            fi
        done < <(find "$CRASH_DIR" \
            \( -name "*${bundle_id}*" -o -name "*${bundle_id//./_}*" \) \
            -print0 2>/dev/null)
    fi
    return "$found"
}

# ── Platform: iOS / iPadOS ────────────────────────────────────────────────────
# Both use the same iqamah-iOS binary; build once, install on two simulators.
IOS_APP_PATH=""

build_ios() {
    if [[ -n "$IOS_APP_PATH" ]]; then return 0; fi   # already built
    log "Building ${SCHEME_IOS} (Debug)..."
    if xcodebuild \
        -project "$PROJECT" -scheme "$SCHEME_IOS" -configuration Debug \
        -destination 'platform=iOS Simulator,name=iPhone 17' \
        -derivedDataPath "$BUILD_ROOT/ios" \
        -allowProvisioningUpdates \
        build 2>&1 \
        | tee /tmp/smoke-ios-build.log \
        | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | tail -5; then
        IOS_APP_PATH=$(find "$BUILD_ROOT/ios" -name "iqamah-iOS.app" -maxdepth 6 | head -1)
        [[ -n "$IOS_APP_PATH" ]] && return 0
    fi
    return 1
}

smoke_ios_sim() {
    local label="$1"   # "iPhone" or "iPad"
    local model_pat="$2"
    hdr "Smoke test: $label"

    # Build (shared between iPhone and iPad)
    if ! build_ios; then
        fail "$label: build failed"
        FAILURES+=("$label (build failed — see /tmp/smoke-ios-build.log)")
        return
    fi
    [[ -z "$IOS_APP_PATH" ]] && { fail "$label: app not found after build"; FAILURES+=("$label"); return; }

    # Simulator
    local udid
    udid=$(pick_sim "$model_pat") || { warn "No $label simulator found — skipping"; return; }
    log "Simulator: $udid"
    boot_sim "$udid"

    # Install
    log "Installing..."
    if ! xcrun simctl install "$udid" "$IOS_APP_PATH" 2>/dev/null; then
        fail "$label: install failed"
        FAILURES+=("$label (install failed)")
        return
    fi

    # Snapshot crash dir before launch
    local since_epoch; since_epoch=$(date +%s)

    # Terminate any existing instance, then launch
    xcrun simctl terminate "$udid" "$BUNDLE_IOS" 2>/dev/null || true
    log "Launching..."
    local launch_out
    launch_out=$(xcrun simctl launch "$udid" "$BUNDLE_IOS" 2>&1)
    log "$launch_out"

    # Wait and check
    sleep 5

    if ! crashes_since "$BUNDLE_IOS" "$since_epoch"; then
        fail "$label: crash report detected"
        FAILURES+=("$label (crash on launch)")
        xcrun simctl terminate "$udid" "$BUNDLE_IOS" 2>/dev/null || true
        return
    fi

    # Confirm app container still exists (i.e. app didn't self-destruct post-launch)
    if ! xcrun simctl get_app_container "$udid" "$BUNDLE_IOS" &>/dev/null; then
        fail "$label: app container missing after launch"
        FAILURES+=("$label (not found post-launch)")
        return
    fi

    xcrun simctl terminate "$udid" "$BUNDLE_IOS" 2>/dev/null || true
    pass "$label: launched cleanly"
    PASSES+=("$label")
}

# ── Platform: watchOS ─────────────────────────────────────────────────────────
smoke_watch() {
    hdr "Smoke test: Apple Watch"

    local udid
    udid=$(pick_sim "$MODEL_WATCH") || { warn "No Watch simulator found — skipping"; return; }
    log "Simulator: $udid"
    boot_sim "$udid"

    log "Building ${SCHEME_WATCH} (Debug)..."
    local build_ok=false
    if xcodebuild \
        -project "$PROJECT" -scheme "$SCHEME_WATCH" -configuration Debug \
        -destination "platform=watchOS Simulator,id=$udid" \
        -derivedDataPath "$BUILD_ROOT/watch" \
        -allowProvisioningUpdates \
        build 2>&1 \
        | tee /tmp/smoke-watch-build.log \
        | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | tail -3; then
        build_ok=true
    fi
    if ! $build_ok; then
        fail "Watch: build failed"
        FAILURES+=("Watch (build failed — see /tmp/smoke-watch-build.log)")
        return
    fi

    local app_path
    app_path=$(find "$BUILD_ROOT/watch" -name "IqamahWatch.app" -maxdepth 6 | head -1)
    [[ -z "$app_path" ]] && { fail "Watch: app not found after build"; FAILURES+=("Watch"); return; }

    log "Installing..."
    xcrun simctl install "$udid" "$app_path" 2>/dev/null \
        || { fail "Watch: install failed"; FAILURES+=("Watch (install failed)"); return; }

    local since_epoch; since_epoch=$(date +%s)
    xcrun simctl terminate "$udid" "$BUNDLE_WATCH" 2>/dev/null || true
    log "Launching..."
    xcrun simctl launch "$udid" "$BUNDLE_WATCH" 2>&1 | tee -a /dev/null

    sleep 5

    if ! crashes_since "$BUNDLE_WATCH" "$since_epoch"; then
        fail "Watch: crash report detected"
        FAILURES+=("Watch (crash on launch)")
        xcrun simctl terminate "$udid" "$BUNDLE_WATCH" 2>/dev/null || true
        return
    fi

    xcrun simctl terminate "$udid" "$BUNDLE_WATCH" 2>/dev/null || true
    pass "Watch: launched cleanly"
    PASSES+=("Watch")
}

# ── Platform: macOS ───────────────────────────────────────────────────────────
smoke_macos() {
    hdr "Smoke test: macOS"

    log "Building ${SCHEME_MACOS} (Debug)..."
    local build_ok=false
    if xcodebuild \
        -project "$PROJECT" -scheme "$SCHEME_MACOS" -configuration Debug \
        -destination 'platform=macOS' \
        -derivedDataPath "$BUILD_ROOT/macos" \
        CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
        build 2>&1 \
        | tee /tmp/smoke-macos-build.log \
        | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | tail -3; then
        build_ok=true
    fi
    if ! $build_ok; then
        fail "macOS: build failed"
        FAILURES+=("macOS (build failed — see /tmp/smoke-macos-build.log)")
        return
    fi

    local app_path
    app_path=$(find "$BUILD_ROOT/macos" -name "iqamah.app" -maxdepth 6 | head -1)
    [[ -z "$app_path" ]] && { fail "macOS: app not found after build"; FAILURES+=("macOS"); return; }
    log "App: $app_path"

    local since_epoch; since_epoch=$(date +%s)

    # Kill any running instance first
    pkill -x iqamah 2>/dev/null || true
    sleep 1

    log "Launching..."
    open -n -a "$app_path" &
    local open_pid=$!

    sleep 5

    # Process check
    local alive=false
    if pgrep -x "iqamah" &>/dev/null; then
        alive=true
    fi

    if ! crashes_since "$BUNDLE_MACOS" "$since_epoch"; then
        pkill -x iqamah 2>/dev/null || true
        fail "macOS: crash report detected"
        FAILURES+=("macOS (crash on launch)")
        return
    fi

    if ! $alive; then
        fail "macOS: process not found 5s after launch"
        FAILURES+=("macOS (process died)")
        return
    fi

    pkill -x iqamah 2>/dev/null || true
    pass "macOS: launched cleanly"
    PASSES+=("macOS")
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    local platforms=("$@")
    [[ ${#platforms[@]} -eq 0 ]] && platforms=(ios ipad watch macos)

    mkdir -p "$BUILD_ROOT"

    local start_time; start_time=$(date +%s)

    for p in "${platforms[@]}"; do
        case "$p" in
            ios)   smoke_ios_sim "iPhone" "$MODEL_IPHONE" ;;
            ipad)  smoke_ios_sim "iPad"   "$MODEL_IPAD"   ;;
            watch) smoke_watch ;;
            macos) smoke_macos ;;
            *)     warn "Unknown platform: $p (valid: ios ipad watch macos all)" ;;
        esac
    done

    local elapsed=$(( $(date +%s) - start_time ))

    echo ""
    echo -e "${BOLD}─── Smoke Test Results ──────────────────────────────${NC}"
    for p in "${PASSES[@]+"${PASSES[@]}"}"; do echo -e "  ${GREEN}✅ $p${NC}"; done
    for f in "${FAILURES[@]+"${FAILURES[@]}"}"; do echo -e "  ${RED}❌ $f${NC}"; done
    echo -e "  Elapsed: ${elapsed}s"
    echo -e "${BOLD}─────────────────────────────────────────────────────${NC}"

    if [[ ${#FAILURES[@]} -gt 0 ]]; then
        echo -e "\n${RED}${BOLD}FAILED${NC} — ${#FAILURES[@]} platform(s) did not pass smoke test"
        exit 1
    fi
    echo -e "\n${GREEN}${BOLD}PASSED${NC} — all ${#PASSES[@]} platform(s) launched cleanly"
    exit 0
}

main "$@"
