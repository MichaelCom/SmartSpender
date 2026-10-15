# Running SmartSpender on iPhone (iOS)

The app is pure Flutter, so no code changes are needed for iOS — only
signing/packaging. This guide covers the prep already done and the exact steps
to build and install on an iPhone.

> **Prerequisite:** a Mac with the **full Xcode** installed (not just the
> command-line tools). This machine currently has only the CLI tools, so the
> signed build must be run after installing Xcode from the App Store:
>
> ```bash
> sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
> sudo xcodebuild -runFirstLaunch
> ```

## Prep already done in this repo

- **Bundle identifier** changed from the Apple-rejected placeholder
  `com.example.smartSpender` to **`com.michaelcombrink.smartspender`**
  (and `.RunnerTests` for the test target) in
  `ios/Runner.xcodeproj/project.pbxproj`.
- **iOS deployment target** set to **13.0** (Podfile, AppFrameworkInfo.plist,
  project.pbxproj) and the Podfile `platform :ios, '13.0'` line uncommented.
- **Display name** is already `Smart Spender`; the **AppIcon set** is fully
  populated in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
- No `NS*UsageDescription` keys are needed: backup export/import uses the
  system document picker + share sheet (file_picker, share_plus), which do not
  require photo-library/contacts permissions on modern iOS.
- Android `applicationId` was intentionally left as `com.example.smart_spender`
  for now so the existing Android install (and its data) is undisturbed. Align
  it later if publishing to Play Store (requires a data backup/restore because
  changing the package makes it a new, separate app).

## Option A — personal device, free (7-day expiry)

Best for just running it on your own iPhone. Apps signed with a free Apple ID
expire after 7 days and must be reinstalled.

```bash
# plug in the iPhone, unlock it, trust the Mac
flutter devices                       # confirm the iPhone is listed
cd ios && pod install && cd ..        # first time, or after plugin changes
flutter run --release -d <iphone-id>  # builds, signs, installs, launches
```

If signing fails, open `ios/Runner.xcworkspace` in Xcode once:
Runner target → Signing & Capabilities → check "Automatically manage signing"
→ pick your personal Apple ID as the Team. Then re-run the command above.

## Option B — Apple Developer Program ($99/yr) + TestFlight (recommended to keep it installed / share)

```bash
flutter build ipa                     # produces build/ios/archive/*.xcarchive
                                      # and build/ios/ipa/*.ipa
```

Then upload to App Store Connect and distribute via TestFlight:
- Open the `.xcarchive` in Xcode Organizer → Distribute App → App Store Connect,
  or use `xcrun altool`/Transporter to upload the `.ipa`.
- In App Store Connect → TestFlight, add yourself/others as testers.
- Builds last 90 days; no per-device UDID registration for TestFlight.

## Option C — ad-hoc ($99/yr, no store)

Register device UDIDs in the Developer portal, build an ad-hoc `.ipa`
(`flutter build ipa --export-method ad-hoc`), and install via Apple
Configurator, Xcode, or a service like Diawi.

## Notes

- Bump `version:` in `pubspec.yaml` (currently `1.0.0+1`) before each
  TestFlight/App Store upload — the build number (`+N`) must increase each time.
- The redesign (theme, shared widgets, all screens) is platform-agnostic Dart
  and already works on iOS.
