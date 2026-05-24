# App Store Connect copy — Iqamah v1.6.0 (15)

This directory holds the marketing copy and submission instructions for the v1.6.0 (15) App Store submission. The text is written once here and pasted into App Store Connect — keeping it in the repo means it's reviewable, diffable, and tracked alongside the code release it describes.

## Structure

```
v1.6.0-build15/
├── README.md                    ← this file
├── archive-instructions.md      ← step-by-step Xcode archive + upload guide
├── ios/
│   ├── promotion-text.txt        ← 170-char-max blurb shown above the description
│   ├── whats-new.md              ← "What's New in This Version" (paste verbatim)
│   └── description.md            ← full app description (paste verbatim or merge with existing)
└── macos/
    ├── promotion-text.txt
    ├── whats-new.md
    └── description.md
```

## Why separate iOS and macOS copy

App Store Connect treats iOS and macOS as separate **platform listings** under the same app record (since Iqamah is configured as a Universal Purchase). Each platform has independent Promotion Text, What's New, Description, and screenshot fields.

We **could** use identical copy on both platforms, but the differentiating UI surfaces are different:

- **iOS** leads with Dynamic Island / Live Activity, Apple Watch companion, and lock-screen widgets.
- **macOS** leads with the always-visible menu bar countdown, Start-on-Login, and Notification Center widgets.

Both versions cover Fasting Mode equally — only the delivery surface in the headline differs.

## How to use these files

1. Open [App Store Connect](https://appstoreconnect.apple.com) → Iqamah → Version 1.6.0
2. Switch between the iOS and macOS platform tabs at the top of the app page
3. For each platform:
   - Paste `promotion-text.txt` into the **Promotional Text** field
   - Paste `whats-new.md` (rendered as plain text) into **What's New in This Version**
   - Paste `description.md` (rendered as plain text) into **Description**
4. Capture and upload screenshots (the one piece this folder cannot generate — see notes in `archive-instructions.md`)

## When to update this copy

- **Promotion Text** can be updated without a new build submission (App Store Connect → Promotional Text field → Save). Useful for tweaking the listing without a binary update.
- **What's New** must be edited as part of a new version submission — once the version is released, it's frozen for that build.
- **Description** can also be updated independently of a build (App Store Connect → App Information → Description), but typically you'd refresh it alongside a major release.
