#!/bin/bash
#
# Builds a release binary and wraps it in ZoneBar.app.
#
# Usage:
#   Scripts/make_app.sh            # build into ./build/ZoneBar.app
#   Scripts/make_app.sh /Applications
#
set -euo pipefail

cd "$(dirname "$0")/.."

DEST="${1:-build}"
APP="$DEST/ZoneBar.app"
BUNDLE_ID="com.timeedit.zonebar"
# Overridable so make_dmg.sh can stamp both the bundle and the disk image with
# the same version.
VERSION="${VERSION:-1.0}"

echo "Building release binary…"
swift build -c release --product ZoneBar

BINARY="$(swift build -c release --product ZoneBar --show-bin-path)/ZoneBar"
if [[ ! -x "$BINARY" ]]; then
    echo "error: binary not found at $BINARY" >&2
    exit 1
fi

# UNIVERSAL=1 also builds an Intel slice so the app runs on Intel Macs. SPM's
# own --arch flag needs full Xcode, so cross-compile separately and lipo the two
# together. Skipped by default because it roughly doubles build time.
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    HOST_ARCH="$(uname -m)"
    if [[ "$HOST_ARCH" == "arm64" ]]; then
        OTHER_TRIPLE="x86_64-apple-macosx14.0"
    else
        OTHER_TRIPLE="arm64-apple-macosx14.0"
    fi

    echo "Building the second architecture ($OTHER_TRIPLE)…"
    swift build -c release --product ZoneBar --scratch-path .build-cross \
        -Xswiftc -target -Xswiftc "$OTHER_TRIPLE" \
        -Xcc -target -Xcc "$OTHER_TRIPLE"

    UNIVERSAL_BINARY="$(mktemp -t zonebar-universal)"
    lipo -create "$BINARY" .build-cross/release/ZoneBar -output "$UNIVERSAL_BINARY"
    BINARY="$UNIVERSAL_BINARY"
    echo "Merged into a universal binary: $(lipo -archs "$BINARY")"
fi

echo "Assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/ZoneBar"

# The icon is optional so the build still works if Resources/ is missing.
ICON_KEYS=""
if [[ -f Resources/AppIcon.icns ]]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
    # CFBundleIconFile is what Finder reads; CFBundleIconName is used by newer
    # APIs and by Get Info.
    ICON_KEYS="    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>"
else
    echo "warning: Resources/AppIcon.icns not found; building without an icon."
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ZoneBar</string>
    <key>CFBundleDisplayName</key>
    <string>ZoneBar</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>
    <string>ZoneBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
$ICON_KEYS
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <!-- Menu-bar only: no Dock icon, no app switcher entry. -->
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signature: enough for local use. Real distribution needs a Developer ID
# identity and notarisation.
codesign --force --sign - "$APP" >/dev/null 2>&1 \
    && echo "Signed ad-hoc." \
    || echo "warning: ad-hoc signing failed; the app should still run locally."

echo "Done: $APP"
echo "Launch with: open \"$APP\""
