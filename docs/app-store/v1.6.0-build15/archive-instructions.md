# Archiving v1.6.0 (15) to App Store Connect

Step-by-step guide for the v1.6.0 build 15 submission. You'll do this in **two passes** — one iOS archive (bundles iPhone + iPad + Apple Watch + widgets + Live Activity) and one macOS archive — even though Iqamah ships across four build targets. App Store Connect treats iOS and macOS as separate platform listings under the same Universal Purchase record.

## Pre-flight (5 min, do once)

1. **Sync local main:**
   ```bash
   cd ~/Projects/iqamah/iqamah
   git checkout main
   git pull origin main
   ```
2. **Open the project in Xcode:**
   ```bash
   open iqamah.xcodeproj
   ```
3. **Confirm Xcode is signed in**: Xcode → Settings → Accounts → Apple ID should show your developer team (`96Y29SP9JR` per project config).
4. **Sanity-check version numbers**: select each target → General → Identity. Should show **Version 1.6.0, Build 15** for:
   - `iqamah` (macOS app)
   - `iqamah-iOS` (iOS app)
   - `IqamahWatch` (watchOS app)
   - `IqamahWidget` (iOS widget extension)
   - `IqamahWidgetMac` (macOS widget extension)
   - `IqamahLiveActivity` (iOS Live Activity extension)
   - `IqamahWatchWidget` (watchOS widget extension)

   If any are out of sync, abort and check `CURRENT_PROJECT_VERSION = 15` and `MARKETING_VERSION = 1.6.0` in the pbxproj for that target's build settings.

## Pass 1 — iOS submission

Bundles iPhone, iPad, Apple Watch companion, widgets, and Live Activity into a single archive.

1. **Scheme**: dropdown next to Run/Stop button → **iqamah-iOS**
2. **Destination**: dropdown next to scheme → **Any iOS Device (arm64)**
   — NOT a simulator.
3. **Archive**: Product menu → **Archive** (or Cmd+Shift+B then Product → Archive). Xcode builds in Release configuration with code signing. Takes 3–5 min.
4. **Organizer window** opens automatically with the new archive selected:
   - Click **Validate App**
   - Select **App Store Connect** distribution
   - Choose **Automatically manage signing**
   - Wait for validation (~1 min)
   - If issues are reported, fix them and re-archive. The Privacy Manifest we shipped in PR #149 should prevent the most common rejection class (`ITMS-91070`).
5. If validation passes, click **Distribute App**:
   - Select **App Store Connect** → **Upload**
   - Same signing options
   - Wait for upload (~3–5 min depending on connection)
6. Once upload completes, the build will show as **Processing** in App Store Connect. Apple takes 10–30 min to process before it's available for TestFlight or for submission to review.

## Pass 2 — macOS submission

Bundles the Mac app + Mac widget extension.

1. **Scheme**: dropdown → **iqamah**
2. **Destination**: **Any Mac (Apple Silicon, Intel)** or **My Mac** (either works — the archive itself is universal).
3. **Product → Archive** — same flow as iOS. Takes 2–4 min.
4. **Organizer** → **Validate App** → **App Store Connect** → automatic signing.
5. If valid, **Distribute App** → **App Store Connect** → Upload.

## After both uploads complete

1. Open **App Store Connect** in a browser: https://appstoreconnect.apple.com
2. **Apps → Iqamah** → confirm both platform listings exist (iOS and macOS tabs at the top of the app page)
3. For each platform's listing:
   - **Build**: pick the just-uploaded 1.6.0 (15) build (will appear once Apple finishes processing)
   - **Promotion Text**: paste from `ios/promotion-text.txt` or `macos/promotion-text.txt`
   - **What's New in This Version**: paste from `ios/whats-new.md` or `macos/whats-new.md`
   - **Description**: paste from `ios/description.md` or `macos/description.md` (or merge with your existing description)
   - **Screenshots**: ⚠️ **the one thing this folder can't generate** — see "Screenshots" section below
   - **Privacy** section: confirm no new data-collection categories (we haven't added any — still no analytics, no servers)
4. **Submit for Review** — pick **Manual release** if you want to control the release date, **Automatic** if you want it to go live as soon as Apple approves.

## Screenshots

Apple requires up-to-date screenshots that reflect the current app state. Since Fasting Mode is the headline new feature, capture at least:

- **Main popover with Fasting Mode banner active** (Ramadan purple gradient, with Suhoor + Iftar times visible)
- **Fasting Mode settings sheet** (master toggle on, several triggers enabled)
- **iOS hero card** in active Ramadan state
- **Apple Watch prayer-times tab** with Fasting Mode indicator
- **Widget gallery** showing the fasting-aware variants

Required sizes (per Apple's current requirements):

| Platform | Required size | Notes |
|----------|---------------|-------|
| iPhone 6.9" (iPhone 17 Pro Max) | 1320 × 2868 | Primary iOS marketing size |
| iPhone 6.5" (iPhone 11 Pro Max) | 1242 × 2688 | Legacy, still required by some apps |
| iPad Pro 13" | 2064 × 2752 | For iPad listing |
| macOS | 1280 × 800 minimum, up to 2880 × 1800 | Use at least 2× retina |
| Apple Watch | 410 × 502 (41mm), 416 × 496 (46mm) | Per the watch sizes in your support matrix |

Best workflow:
1. Open the appropriate simulator (Xcode → Open Developer Tool → Simulator)
2. Set the device, pose the app in the desired state
3. ⌘S (or Device → Screenshot in the simulator menu) to capture to Desktop
4. Drag the resulting PNG into App Store Connect's screenshot uploader

## After submission

- iOS reviews typically take 24–48 hours (sometimes faster)
- macOS reviews usually similar; occasionally slower
- App Store Connect emails you on every state change

## Rejection-risk checklist (already addressed)

The technical-rejection risks we've actively prevented going into this submission:

- ✅ **Privacy Manifest** declared for all 7 targets (PR #149) — avoids `ITMS-91070` and related auto-rejections
- ✅ **CFBundleVersion** atomic at 15 across parent app + every extension (PR #134) — avoids `ITMS-90362` extension-version-mismatch rejections
- ✅ **Watch icon** has a non-black background (accepted in v1.5 build 15) — avoids the Guideline 4 design rejection we hit in v1.5 build 13
- ✅ **No new permission types** or background modes that trigger manual review
- ✅ **Time-sensitive notifications** properly declared; no Critical Alerts entitlement required (avoids manual entitlement review)

## If review rejects

Read the rejection carefully — most rejections at this point would be cosmetic (screenshot mismatch, description issue) rather than technical. Apple's review feedback typically includes:

- Specific guideline number violated
- Steps to reproduce the issue (for behavioral problems)
- Screenshots or video evidence (for visual problems)

Apple Reviewer team responses can be replied to via Resolution Center in App Store Connect — substantive responses (e.g., "this is intentional because…") often help resolve issues without re-submitting.
