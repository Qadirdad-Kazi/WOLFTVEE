#!/usr/bin/env bash
# Build WOLFTVEE for shipping platforms (no iOS).
# Usage:
#   ./scripts/build_all.sh              # all available platforms
#   ./scripts/build_all.sh macos android
#   ./scripts/build_all.sh android      # APK for phone + Fire Stick / Android TV
#
# Always:
#   • Ad-hoc codesigns macOS.app (FREE — no Apple Developer account)
#   • Copies outputs to ~/Downloads and ~/Downloads/WOLFTVEE-builds/<stamp>/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${WOLFTVEE_OUT:-$HOME/Downloads/WOLFTVEE-builds}"
STAMP="$(date +%Y%m%d-%H%M%S)"
DEST="$OUT/$STAMP"
DOWNLOADS="$HOME/Downloads"

cd "$ROOT"

TARGETS=("${@:-}")
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=(macos android)
  if [[ -d windows ]]; then
    TARGETS+=(windows)
  fi
fi

mkdir -p "$DEST" "$DOWNLOADS"
echo "==> Output: $DEST"
echo "==> Also:   $DOWNLOADS"
echo "==> Targets: ${TARGETS[*]}"

flutter pub get

# Free ad-hoc sign (no paid Apple Developer account). Required so nested
# media_kit frameworks (Ass.framework, Mpv, …) load on modern macOS.
sign_macos_app() {
  local app="$1"
  echo "    → Ad-hoc signing (auto, free)…"
  xattr -cr "$app" 2>/dev/null || true

  # Sign nested frameworks/dylibs first, then the bundle (more reliable than
  # --deep alone on some Xcode versions).
  while IFS= read -r -d '' fw; do
    codesign --force --sign - --timestamp=none "$fw" 2>/dev/null || true
  done < <(find "$app/Contents/Frameworks" -name '*.framework' -print0 2>/dev/null)

  codesign --force --deep --sign - --timestamp=none "$app"
  codesign --verify --deep --strict "$app"
  echo "    → Signature OK"
}

build_macos() {
  echo "==> Building macOS release…"
  local app=""

  # Prefer /tmp DerivedData — avoids intermittent build.db disk I/O failures
  # when the project disk is nearly full.
  rm -rf build/macos
  flutter build macos --config-only --release
  (cd macos && pod install --silent 2>/dev/null || pod install)

  local dd="/tmp/wolftvee_xcode_dd_$$"
  rm -rf "$dd"
  if xcodebuild \
      -workspace macos/Runner.xcworkspace \
      -scheme Runner \
      -configuration Release \
      -derivedDataPath "$dd" \
      -destination 'platform=macOS,arch=arm64' \
      ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
      build; then
    app="$dd/Build/Products/Release/WOLFTVEE.app"
  else
    echo "    xcodebuild (/tmp) failed — trying flutter build macos…"
    flutter build macos --release
    app="build/macos/Build/Products/Release/WOLFTVEE.app"
  fi

  if [[ ! -d "$app" ]]; then
    echo "ERROR: macOS app not found at $app" >&2
    exit 1
  fi

  # Confirm wolf logo shipped in the bundle.
  local logo="$app/Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets/assets/brand/wolf_logo.jpeg"
  if [[ ! -f "$logo" ]]; then
    echo "ERROR: wolf_logo.jpeg missing from app bundle — check pubspec assets." >&2
    exit 1
  fi

  sign_macos_app "$app"

  rm -rf "$DEST/WOLFTVEE.app" "$DOWNLOADS/WOLFTVEE.app"
  cp -R "$app" "$DEST/WOLFTVEE.app"
  cp -R "$app" "$DOWNLOADS/WOLFTVEE.app"

  # Shareable zip (already signed — users should not re-sign).
  rm -f "$DOWNLOADS/WOLFTVEE-macOS.zip" "$DEST/WOLFTVEE-macOS.zip"
  ditto -c -k --sequesterRsrc --keepParent "$DOWNLOADS/WOLFTVEE.app" \
    "$DOWNLOADS/WOLFTVEE-macOS.zip"
  cp "$DOWNLOADS/WOLFTVEE-macOS.zip" "$DEST/WOLFTVEE-macOS.zip"

  echo "    ✓ $DEST/WOLFTVEE.app"
  echo "    ✓ $DOWNLOADS/WOLFTVEE.app"
  echo "    ✓ $DOWNLOADS/WOLFTVEE-macOS.zip"
}

build_android() {
  echo "==> Building Android APK (phone + Fire Stick / Android TV)…"
  flutter build apk --release
  local apk="build/app/outputs/flutter-apk/app-release.apk"
  if [[ ! -f "$apk" ]]; then
    echo "ERROR: APK not found at $apk" >&2
    exit 1
  fi

  # Logo check is informational only (do not fail the build).
  if python3 - "$apk" <<'PY'
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
sys.exit(0 if any("wolf_logo.jpeg" in n for n in z.namelist()) else 1)
PY
  then
    echo "    → wolf logo present in APK"
  else
    echo "    WARNING: wolf_logo.jpeg not listed in APK zip index"
  fi

  cp "$apk" "$DEST/WOLFTVEE-android.apk"
  cp "$apk" "$DOWNLOADS/WOLFTVEE-android.apk"
  echo "    ✓ $DEST/WOLFTVEE-android.apk"
  echo "    ✓ $DOWNLOADS/WOLFTVEE-android.apk"
  echo "    Tip: ONE APK for phone + Android TV + Fire Stick."
  echo "         TV/Fire Stick: sideload → Apps row (LEANBACK_LAUNCHER)."
  echo "         Phone: normal install (LAUNCHER)."
}

build_windows() {
  if [[ ! -d windows ]]; then
    echo "==> Skipping Windows (platform folder missing). Run:"
    echo "    flutter create --platforms=windows ."
    return 0
  fi
  echo "==> Building Windows release…"
  flutter build windows --release
  local dir="build/windows/x64/runner/Release"
  if [[ ! -d "$dir" ]]; then
    dir="build/windows/runner/Release"
  fi
  rm -rf "$DEST/WOLFTVEE-windows"
  mkdir -p "$DEST/WOLFTVEE-windows"
  cp -R "$dir/"* "$DEST/WOLFTVEE-windows/"
  echo "    ✓ $DEST/WOLFTVEE-windows/"
}

for t in "${TARGETS[@]}"; do
  case "$t" in
    macos|mac) build_macos ;;
    android|apk|tv|firestick) build_android ;;
    windows|win) build_windows ;;
    ios)
      echo "Skipping iOS (not used for this project)."
      ;;
    *)
      echo "Unknown target: $t (use macos|android|windows)"
      exit 1
      ;;
  esac
done

# Combined pack for sharing with users
if [[ -f "$DOWNLOADS/WOLFTVEE-android.apk" ]] || [[ -d "$DOWNLOADS/WOLFTVEE.app" ]]; then
  SHARE="$DEST/WOLFTVEE-for-users"
  rm -rf "$SHARE"
  mkdir -p "$SHARE"
  [[ -d "$DOWNLOADS/WOLFTVEE.app" ]] && cp -R "$DOWNLOADS/WOLFTVEE.app" "$SHARE/"
  [[ -f "$DOWNLOADS/WOLFTVEE-android.apk" ]] && cp "$DOWNLOADS/WOLFTVEE-android.apk" "$SHARE/"
  cat > "$SHARE/README.txt" <<EOF
WOLFTVEE — $STAMP

macOS: Right-click WOLFTVEE.app → Open (first time).
  Already ad-hoc signed — do NOT re-sign or strip signatures.

Android / Fire Stick / Android TV:
  Install the SAME file: WOLFTVEE-android.apk
EOF
  ditto -c -k --sequesterRsrc --keepParent "$SHARE" \
    "$DOWNLOADS/WOLFTVEE-for-users.zip"
  cp "$DOWNLOADS/WOLFTVEE-for-users.zip" "$DEST/WOLFTVEE-for-users.zip"
fi

cat > "$DEST/README.txt" <<EOF
WOLFTVEE builds — $STAMP

Also copied to ~/Downloads/:
  - WOLFTVEE.app / WOLFTVEE-macOS.zip   (macOS, auto ad-hoc signed)
  - WOLFTVEE-android.apk               (phone + TV + Fire Stick)
  - WOLFTVEE-for-users.zip             (share pack)

Fire Stick / Android TV:
  1. Enable Apps from Unknown Sources / ADB.
  2. Install WOLFTVEE-android.apk.
  3. Launch from Apps row — D-pad focus on TV only.

macOS:
  Open WOLFTVEE.app (already signed by the build script).
  First open: right-click → Open if Gatekeeper warns.

See docs/BUILD.md and docs/SHARE.md.
EOF

echo ""
echo "==> Done. Artifacts:"
ls -lah "$DEST"
echo ""
echo "==> Downloads shortcuts:"
ls -lah \
  "$DOWNLOADS/WOLFTVEE.app" \
  "$DOWNLOADS/WOLFTVEE-macOS.zip" \
  "$DOWNLOADS/WOLFTVEE-android.apk" \
  "$DOWNLOADS/WOLFTVEE-for-users.zip" \
  2>/dev/null || true
