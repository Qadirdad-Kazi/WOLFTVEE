# WOLFTVEE — multi-platform builds

This project ships **macOS**, **Android (phone + Fire Stick / Android TV)**, and optionally **Windows**. **iOS is not used.**

## One-shot script

```bash
chmod +x scripts/build_all.sh
./scripts/build_all.sh
```

Artifacts land in:

- `~/Downloads/WOLFTVEE-builds/<timestamp>/`
- Convenience copies: `~/Downloads/WOLFTVEE.app` and `~/Downloads/WOLFTVEE-android.apk`

### Selective targets

```bash
./scripts/build_all.sh macos
./scripts/build_all.sh android          # same APK for phone + TV / Fire Stick
./scripts/build_all.sh macos android
./scripts/build_all.sh windows          # requires windows/ platform folder
```

Override output root:

```bash
WOLFTVEE_OUT=/path/to/folder ./scripts/build_all.sh
```

## Manual commands

| Platform | Command | Output |
|----------|---------|--------|
| macOS | `flutter build macos --release` | `build/macos/Build/Products/Release/WOLFTVEE.app` |
| Android APK | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` |
| Android App Bundle | `flutter build appbundle --release` | `build/app/outputs/bundle/release/app-release.aab` |
| Windows | `flutter build windows --release` | `build/windows/x64/runner/Release/` |
| iOS | — | **Not used** |

Prefer `./scripts/build_all.sh macos` — it ad-hoc signs nested **media_kit** frameworks (`Ass.framework`, `Mpv.framework`, …). An unsigned copy crashes at launch on modern macOS:

```text
Library not loaded: @rpath/Ass.framework/... (missing code signature)
```

Manual fix if needed:

```bash
xattr -cr ~/Downloads/WOLFTVEE.app
codesign --force --deep --sign - ~/Downloads/WOLFTVEE.app
```

Enable Windows once (if missing):

```bash
flutter create --platforms=windows .
```

## Fire Stick / Android TV

One APK covers **phone**, **Android TV**, and **Fire Stick**.

1. Build: `./scripts/build_all.sh android`
2. Sideload `WOLFTVEE-android.apk` (ADB, Apps2Fire, Downloader, etc.)
3. Open from the Apps / Games row (Leanback launcher)

### Input

| Input | Behavior |
|-------|----------|
| **D-pad / remote** | Focus rings (lime), Select/Enter activates |
| **Mouse / Air Mouse** | Click works on the same controls |
| **Phone / macOS / Windows** | **No** TV focus chrome — normal tap / click UI |

TV mode is detected at runtime via Android leanback / Fire TV features (`WolfTv.isTv`). Screen size alone never enables it.

### ADB sideload example

```bash
adb connect <firestick-ip>:5555
adb install -r ~/Downloads/WOLFTVEE-android.apk
```

## Prerequisites

- Flutter SDK matching the project (`sdk: ^3.12.2` in `pubspec.yaml`)
- `.env` present (copy from `.env.example`)
- macOS builds: Xcode
- Android builds: Android SDK + accepted licenses (`flutter doctor --android-licenses`)
- Windows builds: Visual Studio with Desktop C++ workload (on a Windows machine or CI)

> Android uses AGP **8.9.x** (not 9.x) so `flutter_inappwebview` can still resolve
> `proguard-android.txt`. Keep that pin until the plugin updates.

## Notes

- Clean rebuild: `flutter clean && ./scripts/build_all.sh`
- Release signing for Play Store needs your own keystore (debug/release unsigned APK is fine for sideload)
- Cleartext traffic is disabled; streams must be HTTPS
