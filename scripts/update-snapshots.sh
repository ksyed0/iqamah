#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# scripts/update-snapshots.sh — Re-record all snapshot reference images
#
# Run this whenever a view's appearance changes intentionally and you want to
# accept the new rendering as the new reference:
#
#   bash scripts/update-snapshots.sh
#
# After running, review the updated PNGs in Tests/__Snapshots__/ and commit.
# AC-0316 (US-0065, EPIC-0015)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

PROJECT="iqamah.xcodeproj"
SCHEME="iqamah"

echo "Re-recording all snapshot reference images…"
echo "Snapshots will be written to Tests/__Snapshots__/"
echo ""

xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination 'platform=macOS' \
    -only-testing:iqamahTests/MoonPhaseSnapshotTests \
    -only-testing:iqamahTests/QiblahCompassSnapshotTests \
    -only-testing:iqamahTests/PrayerTimesTableSnapshotTests \
    -only-testing:iqamahTests/FastingBannerSnapshotTests \
    -only-testing:iqamahTests/FastingModeSectionSnapshotTests \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    ENABLE_HARDENED_RUNTIME=NO \
    RECORD_SNAPSHOTS=YES \
    2>&1 | grep -E "Recorded snapshot|error:|Test Case" | head -30 || true

echo ""
echo "Done.  Review the new images in Tests/__Snapshots__/ then commit them."
