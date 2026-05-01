# Image Generation Prompts — Iqamah

Paste these prompts directly into Midjourney, DALL·E 3, Stable Diffusion, or Adobe Firefly.

---

## 1. App Icon

**Use for:** `Assets.xcassets` app icon set (export at 1024×1024 PNG, no transparency, no rounded corners — macOS applies the mask)

---

**Prompt:**

> A square app icon for a macOS Islamic prayer times application. The design features a single elegant gold minaret silhouette centred on a deep navy blue to dark teal gradient background. The minaret has a crescent moon at the top, a decorative dome, a balcony ring, a tapered tower body, and a wide base. The minaret is rendered in a warm metallic gold gradient (amber at top, deep gold at base). The background uses a subtle radial glow — slightly lighter teal near the centre fading to near-black navy at the corners, evoking a night sky. The overall aesthetic is minimal, flat with slight depth, modern Islamic geometric. No text. No shadows outside the icon boundary. High contrast. Crisp edges. Professional macOS app icon quality. Square format 1:1.

**Negative prompt (if supported):** text, letters, busy background, photo-realistic, 3D render, excessive detail, rounded corners

---

## 2. Splash Screen Background

**Use for:** `splash.jpg` — shown for 2 seconds on launch (app overlays prayer reminder text in white/black on top)

**Target size:** 900×700 px minimum, landscape, JPEG

---

**Prompt:**

> A serene, photorealistic landscape of a historic mosque at golden hour. The mosque has a single tall minaret silhouetted against a sky that transitions from deep indigo at the top through warm amber and gold at the horizon. Star trails or a crescent moon are faintly visible in the upper sky. Soft warm light glows from the mosque windows. A calm reflecting pool or stone courtyard in the foreground. The image is wide landscape format, slightly desaturated and atmospheric — like a long-exposure photograph. The centre-lower portion of the image should have a relatively clear, lighter sky or smooth foreground area suitable for overlaying white or black text without losing legibility. No people. No text. Cinematic, tranquil, deeply spiritual atmosphere. 16:9 landscape.

**Style keywords:** golden hour, cinematic photography, long exposure, atmospheric, Islamic architecture

**Alternative simpler prompt (for DALL·E 3):**

> Cinematic wide landscape photograph of an illuminated mosque minaret at dusk. Deep blue-purple sky with a crescent moon and stars. Warm amber light from mosque windows reflecting on a stone courtyard. Peaceful, spiritual atmosphere. No people, no text. Wide 16:9 landscape format.

---

## 3. Qiblah Compass Prayer Mat Illustration

**Use for:** The central compass element in QiblahView (export as SVG or PNG with transparency)

**Target size:** 200×280 px, transparent background

---

**Prompt:**

> A top-down flat illustration of a traditional Islamic prayer mat (sajadah) seen from directly above. The mat is rectangular, taller than wide (portrait orientation, approximately 2:3 ratio). The mat has a rich emerald green base with intricate geometric border patterns in gold thread along all four edges. At the top (the direction of prayer) there is a pointed Moorish arch (mihrab) motif woven into the fabric in gold and dark green. The interior of the mat shows a subtle repeating geometric tessellation pattern in slightly lighter green. The overall style is flat vector illustration — clean lines, no shadows, no gradients except subtle fabric texture. Transparent background. The mat appears as if laid flat, viewed from directly above (orthographic top-down view). No person praying on it.

**Negative prompt:** person, hands, realistic photo, 3D, shadows, perspective distortion, background

---

## 4. Ka'bah Icon for Qiblah Compass

**Use for:** `KaabahIcon.imageset` in Assets.xcassets — the small marker placed on the compass ring at the Qiblah bearing in `QiblahView`. Replaces the current programmatic `KaabahMarker` SwiftUI view.

**Target size:** Export at 3 sizes — 44×44 (@1x), 88×88 (@2x), 132×132 (@3x) — PNG with transparent background.

**Design context:** The icon sits on a compass ring at a radius of ~140pt from centre. It needs to be immediately recognisable as the Ka'bah at small sizes (as small as 22pt rendered). It is rotated by the SwiftUI engine to the correct compass bearing, so it must look correct from any rotation angle — avoid directional elements like shadows or highlights that imply a fixed light source.

---

**Primary prompt (vector-style, best for Midjourney / Firefly):**

> A minimal flat icon of the Ka'bah (the cubic shrine at the centre of Masjid al-Haram in Makkah). The design is a perfect square or slightly portrait rectangle viewed from a 3/4 isometric angle — just enough depth to read as a cube, not fully flat. The body of the Ka'bah is rendered in near-black (deep charcoal, #1a1a1a). A continuous gold band (the Kiswa girdle) wraps the upper third of the cube, rendered in warm metallic gold (#C8962A). The band has a very subtle geometric or calligraphic texture implied, not detailed. The roof has a slim gold ledge overhang. No door detail needed at this scale. The background is fully transparent. The overall style is modern flat iconography with 1–2pt gold border stroke. Crisp, high-contrast, recognisable at 22×22pt. No text. No shadows. No glow. Transparent background. Square canvas.

**Negative prompt:** realistic photo, 3D render, people, mosque surroundings, arabic text, ornate decoration, drop shadow, background colour, pilgrims, Tawaf

---

**Alternative prompt (for DALL·E 3, more literal):**

> A small square app icon of the Ka'bah — the sacred black cubic structure in Mecca. Minimal flat illustration, dark charcoal cube with a gold horizontal band across the upper portion representing the Kiswa gold embroidered belt. Slight isometric perspective so it reads as a 3D cube. Clean vector aesthetic. Transparent background. No people, no surroundings, no text. Crisp edges for use at small sizes.

---

**Midjourney parameter suggestions:**
```
--style raw --stylize 200 --ar 1:1 --no shadow, background, text, people
```

---

**Usage notes:**
- The icon is placed at `offset(x: 140 * sin(bearing), y: -140 * cos(bearing))` on the compass ring — it rotates with the ring, so the design must be rotationally neutral (no fixed light direction)
- Export with transparency; the compass background is white/light grey in light mode and dark in dark mode — test legibility in both
- Once exported, add to `Assets.xcassets/KaabahIcon.imageset/` and update `QiblahView.swift` to replace `KaabahMarker()` with `Image("KaabahIcon").resizable().frame(width: 22, height: 22)`

---

## 5. App Store Feature Graphic / Hero Image

**Use for:** App Store promotional artwork (optional but recommended — 1920×1080 px)

---

**Prompt:**

> A clean, modern promotional banner for a macOS Islamic prayer times app called "Iqamah". On the left side, a stylised dark navy blue macOS window showing a prayer times list — Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha — with one row highlighted in gold/amber accent colour and a monospaced time like "7:42 PM". On the right side, a circular compass with a prayer mat pointing toward a small Ka'bah icon on the compass ring. The background is a deep gradient — dark navy blue (#1a2a3a) to dark teal (#0a1e2a). Minimal UI, gold and white text on dark background. App name "Iqamah" in large serif font at the top in gold. Subtitle "Prayer Times for Mac" in white below. Flat modern aesthetic, macOS HIG compliant style, no shadows. Wide 16:9 banner format.

---

## Notes on Usage

- **App icon:** Do not add rounded corners yourself. macOS applies the standard squircle mask automatically. Submit the icon as a full-square 1024×1024 PNG with no alpha channel.
- **Splash:** The app overlays text on the splash image. Keep the lower-centre region relatively uncluttered. Avoid pure white or pure black splash backgrounds — mid-toned images give the overlaid text the best contrast.
- **Prayer mat:** The QiblahView rotates the mat programmatically to face Makkah — ensure the top of the mat design is the "Qiblah end" (the arch/mihrab end faces up in the raw asset).
