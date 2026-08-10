#!/bin/bash
#
# Builds ZoneBar.app and wraps it in a distributable disk image.
#
# Usage:
#   Scripts/make_dmg.sh              # build/ZoneBar-1.0.dmg
#   VERSION=1.2 Scripts/make_dmg.sh  # build/ZoneBar-1.2.dmg
#
# Needs only the Command Line Tools — hdiutil is part of the base system.
#
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${VERSION:-1.0}"
export VERSION

VOLUME_NAME="ZoneBar"
STAGING="build/dmg-staging"
DMG="build/ZoneBar-$VERSION.dmg"

# Build the app straight into the staging folder so the image contains exactly
# what we just built.
rm -rf "$STAGING"
mkdir -p "$STAGING"
Scripts/make_app.sh "$STAGING"

# The /Applications alias is what makes the usual "drag to install" work.
ln -s /Applications "$STAGING/Applications"

# A short README travels with the image because an ad-hoc signed app trips
# Gatekeeper on machines other than the one that built it.
cat > "$STAGING/Read Me.txt" <<'TXT'
ZoneBar
=======

To install: drag ZoneBar to the Applications folder alongside this file.

ZoneBar lives in the menu bar, so it has no Dock icon. After launching it, look
for the clock in the menu bar. Open its menu and choose "Settings…" to add time
zones and switch between Flat and Grouped display.

First launch
------------
This build is signed ad-hoc rather than with a Developer ID, so macOS will
refuse to open it on the first try. To allow it:

  Right-click (or Control-click) ZoneBar in Applications, choose "Open", then
  confirm "Open" in the dialog.

Alternatively, remove the download quarantine flag from Terminal:

  xattr -dr com.apple.quarantine /Applications/ZoneBar.app

To remove ZoneBar, quit it from its menu and drag it to the Trash.
TXT

[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$STAGING/.VolumeIcon.icns"

# Build read/write first. The custom-icon flag has to be set on the mounted
# volume's root — setting it on the staging folder does not carry into the image,
# because hdiutil creates a fresh filesystem.
TEMP_DMG="build/ZoneBar-rw.dmg"
MOUNT_POINT="build/dmg-mount"

cleanup() {
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    rm -rf "$MOUNT_POINT" "$TEMP_DMG"
}
trap cleanup EXIT

echo "Creating $DMG…"
rm -f "$DMG" "$TEMP_DMG"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING" \
    -fs HFS+ \
    -format UDRW \
    -ov \
    "$TEMP_DMG" >/dev/null

if [[ -f Resources/AppIcon.icns ]]; then
    mkdir -p "$MOUNT_POINT"
    # An explicit mountpoint keeps this image separate from anything else the
    # user already has mounted.
    hdiutil attach "$TEMP_DMG" -mountpoint "$MOUNT_POINT" -nobrowse -quiet
    if SetFile -a C "$MOUNT_POINT" 2>/dev/null; then
        echo "Volume icon set."
    else
        echo "warning: could not set the volume icon attribute; using the default."
    fi
    hdiutil detach "$MOUNT_POINT" -quiet
fi

# Compress into the final read-only image.
hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG" >/dev/null

rm -rf "$STAGING"

echo "Verifying…"
hdiutil verify "$DMG" >/dev/null && echo "Image verified."

SIZE="$(du -h "$DMG" | cut -f1)"
echo "Done: $DMG ($SIZE)"
