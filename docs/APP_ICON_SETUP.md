# App Icon Setup Instructions

## Generating the App Icon

The app includes a programmatically generated app icon featuring a golden minaret with a stylized lowercase "i".

### Steps to Export and Set Up the App Icon:

1. **Export Icon Files:**
   - Open the project in Xcode
   - Add a preview or temporary view to display `AppIconExporterView`
   - Click the "Export Icon Files to Desktop" button
   - This will create a folder called `IqamahIcons` on your Desktop with all required sizes

2. **Add Icons to Asset Catalog:**
   - Open your project's Asset Catalog (`Assets.xcassets`)
   - Find or create an "AppIcon" asset
   - Drag the exported PNG files to the appropriate size slots:
     - icon_16x16.png → 16pt slot
     - icon_32x32.png → 16pt @2x slot
     - icon_32x32.png → 32pt slot
     - icon_64x64.png → 32pt @2x slot
     - icon_128x128.png → 128pt slot
     - icon_256x256.png → 128pt @2x slot
     - icon_256x256.png → 256pt slot
     - icon_512x512.png → 256pt @2x slot
     - icon_512x512.png → 512pt slot
     - icon_1024x1024.png → 512pt @2x slot

3. **Set the App Icon in Project Settings:**
   - Select your project in Xcode
   - Go to your app target
   - In the "General" tab, under "App Icons and Launch Screen"
   - Set "App Icon" to use the AppIcon asset

## Manual Icon Creation (Alternative)

If you prefer to create the icon manually or want to customize it:

1. The `AppIconView.swift` file contains the complete SwiftUI implementation
2. You can modify colors, shapes, or proportions directly in the code
3. Re-export using the `AppIconGenerator` utility

## Icon Design Details

- **Background:** Dark blue gradient (#26394D to #141925)
- **Minaret:** Golden gradient (#F2C20F to #D9A521)
- **Letter "i":** Golden gradient with serif font
- **Style:** Minimalist, elegant, with Islamic architectural elements

## Previewing the Icon

The icon is now integrated into:
- ✅ Splash screen (top center, 180×180pt)
- ✅ Prayer times screen (header, 48×48pt with app name)
- ✅ Can be exported as actual app icon files

## Testing

After setting up the app icon:
1. Build and run the app
2. Check the Dock to see your new icon
3. The icon should also appear in Finder, Application folder, and Launchpad
