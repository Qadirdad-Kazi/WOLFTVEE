# Sharing WOLFTVEE without a paid Apple Developer account

## Important

**Ad-hoc code signing is free.** It is **not** the $99/year Apple Developer Program.

macOS **requires** some signature on nested frameworks (`Ass.framework` from the video player).  
If you distribute a fully **unsigned** `.app`, it **crashes on launch** for everyone.

You do **not** need:
- Apple Developer Program enrollment  
- App Store Connect  
- Notarization (optional; only for “double-click with no warnings”)

You **do** need:
- The build already ad-hoc signed (`codesign --sign -`), which `./scripts/build_all.sh macos` does

## What to send users

| Platform | File | How they install |
|----------|------|------------------|
| **macOS** | `WOLFTVEE-macOS.zip` or `WOLFTVEE.app` | Unzip → **right-click → Open** the first time |
| **Android phone** | `WOLFTVEE-android.apk` | Enable “Install unknown apps” → open APK |
| **Android TV / Fire Stick** | **Same** `WOLFTVEE-android.apk` | Sideload (Downloader / ADB) |

Combined pack: `~/Downloads/WOLFTVEE-for-users.zip`

## macOS first-open (Gatekeeper)

Friends may see “cannot be opened because the developer cannot be verified.”

That is normal without notarization. Tell them:

1. Right-click **WOLFTVEE.app** → **Open** → **Open**
2. Or Terminal: `xattr -cr /path/to/WOLFTVEE.app && open /path/to/WOLFTVEE.app`

## Do not

- Disable code signing when building (`CODE_SIGNING_ALLOWED=NO`) — causes Ass.framework crash  
- Strip signatures before sending  
- Expect zero Gatekeeper prompts without paid Developer ID + notarization  

## Rebuild for sharing

```bash
./scripts/build_all.sh macos android
# Artifacts land in ~/Downloads/ and ~/Downloads/WOLFTVEE-builds/<stamp>/
```
