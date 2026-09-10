#!/usr/bin/env bash
# Build WOLFTVEE for shipping platforms (no iOS).
# Usage:
#   ./scripts/build_all.sh              # all available platforms
#   ./scripts/build_all.sh macos android
#   ./scripts/build_all.sh android      # APK for phone + Fire Stick / Android TV
set -euo pipefail
# Fail the whole script if any platform build fails

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${WOLFTVEE_OUT:-$HOME/Downloads/WOLFTVEE-builds}"
STAMP="$(date +%Y%m%d-%H%M%S)"
DEST="$OUT/$STAMP"

cd "$ROOT"

TARGETS=("${@:-}")
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=(macos android)
  if [[ -d windows ]]; then
    TARGETS+=(windows)
  fi
fi

mkdir -p "$DEST"
echo "==> Output: $DEST"
echo "==> Targets: ${TARGETS[*]}"

flutter pub get

build_macos() {
  echo "==> Building macOS release…"
  flutter build macos --release
  local app="build/macos/Build/Products/Release/WOLFTVEE.app"
  rm -rf "$DEST/WOLFTVEE.app" "$HOME/Downloads/WOLFTVEE.app"
  cp -R "$app" "$DEST/WOLFTVEE.app"
  cp -R "$app" "$HOME/Downloads/WOLFTVEE.app"
  echo "    ✓ $DEST/WOLFTVEE.app"
  echo "    ✓ $HOME/Downloads/WOLFTVEE.app"
}

build_android() {
  echo "==> Building Android APK (phone + Fire Stick / Android TV)…"
  flutter build apk --release
  local apk="build/app/outputs/flutter-apk/app-release.apk"
  cp "$apk" "$DEST/WOLFTVEE-android.apk"
  cp "$apk" "$HOME/Downloads/WOLFTVEE-android.apk"
  echo "    ✓ $DEST/WOLFTVEE-android.apk"
  echo "    ✓ $HOME/Downloads/WOLFTVEE-android.apk"
  echo "    Tip: same APK installs on Fire Stick / Android TV boxes."
  echo "         TV focus mode activates only on leanback / Fire TV devices."
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

cat > "$DEST/README.txt" <<EOF
WOLFTVEE builds — $STAMP

Platforms in this folder:
$(ls -1 "$DEST" | sed 's/^/  - /')

Fire Stick / Android TV:
  1. Enable Apps from Unknown Sources / ADB.
  2. Install WOLFTVEE-android.apk (sideload via adb or Downloader).
  3. Launch from Apps row — D-pad focus + mouse both work.
  4. Phone APK is the same file; focus chrome stays OFF on phones.

macOS:
  Open WOLFTVEE.app (also copied to ~/Downloads/WOLFTVEE.app).

Windows:
  Run WOLFTVEE.exe inside WOLFTVEE-windows/.

See docs/BUILD.md for details.
EOF

echo ""
echo "==> Done. Artifacts in $DEST"
ls -lah "$DEST"
