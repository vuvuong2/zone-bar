# ZoneBar

A macOS menu-bar app showing the time in several time zones, each with its
country's flag.

A single **Display mode** switch drives the whole app:

| Mode        | Menu bar                          | Dropdown                       |
| ----------- | --------------------------------- | ------------------------------ |
| **Flat**    | every clock inline — `🇸🇪 10:30  🇯🇵 17:30` | one flat list          |
| **Grouped** | the primary clock only — `🇯🇵 17:30`        | sections by region     |

Region sections are derived from the IANA zone name and ordered Americas →
Europe → Africa → Asia → Oceania → Other.

## Build and run

Needs Swift 5.9+. Xcode is **not** required — the Command Line Tools are enough.

```bash
Scripts/make_app.sh          # build ZoneBar.app into ./build
open build/ZoneBar.app
```

To install it, pass a destination:

```bash
Scripts/make_app.sh /Applications
```

## Download

[`ZoneBar-1.0.dmg`](ZoneBar-1.0.dmg) in the repository root is a prebuilt
universal image (arm64 + x86_64, macOS 14+). See **Installing on another Mac**
below for the Gatekeeper step needed on first launch.

Rebuild it with `UNIVERSAL=1 Scripts/make_dmg.sh` and copy the result over this
file to publish a new version.

## Building a DMG

```bash
Scripts/make_dmg.sh
```

Produces `build/ZoneBar-1.0.dmg` containing the app, an `/Applications` alias to
drag onto, and a short Read Me. The mounted volume uses the app icon. Override
the version with `VERSION=1.2 Scripts/make_dmg.sh`, which stamps both the bundle
and the image name.

The image is checksum-verified as part of the build.

## Installing on another Mac

Copy the DMG over, open it, and drag ZoneBar to Applications. Two caveats:

**Architecture.** A plain build contains only the host architecture, so an
arm64 build will not launch on an Intel Mac (Rosetta cannot run arm64 on Intel).
Build a universal binary to cover both:

```bash
UNIVERSAL=1 Scripts/make_dmg.sh
```

That cross-compiles the second architecture and merges the slices with `lipo`.
It needs no Xcode, and roughly doubles build time. Check the result with
`lipo -archs build/ZoneBar.app/Contents/MacOS/ZoneBar`.

**Gatekeeper.** The app is signed ad-hoc, so macOS blocks the first launch on
any machine other than the one that built it — right-click the app and choose
**Open**, or run `xattr -dr com.apple.quarantine /Applications/ZoneBar.app`.
The bundled Read Me repeats these steps for whoever installs it.

The app requires macOS 14 or later. Shipping without the Gatekeeper friction
needs a Developer ID identity plus notarisation:

```bash
codesign --force --deep --options runtime \
    --sign "Developer ID Application: NAME (TEAMID)" build/ZoneBar.app
xcrun notarytool submit build/ZoneBar-1.0.dmg \
    --apple-id you@example.com --team-id TEAMID --wait
xcrun stapler staple build/ZoneBar-1.0.dmg
```

During development you can skip the bundle and run the binary directly:

```bash
swift build && .build/debug/ZoneBar
```

## Tests

```bash
swift run ZoneBarTests
```

XCTest ships inside Xcode rather than the Command Line Tools, so `swift test`
cannot run here. The suite is a plain executable with a small harness in
`Tests/ZoneBarTests/TestHarness.swift`; it exits non-zero on failure, so it
works in CI unchanged.

## Inspecting state without the UI

```bash
build/ZoneBar.app/Contents/MacOS/ZoneBar --print-state
```

Prints the menu-bar string and the dropdown rows for the stored preferences,
then exits. Useful for checking what the app will render.

## Layout

```
Sources/ZoneBarCore/     models, services and menu construction — no AppKit
  Models/                Clock, Preferences, DisplayMode
  Services/              TimeZoneCatalog, FlagEmoji, ClockFormatter, PreferencesStore
  MenuBar/MenuBuilder    pure (Preferences, Date) -> title + rows
  Generated/             time zone -> country table
Sources/ZoneBar/         app shell: NSStatusItem, SwiftUI settings window
Tests/ZoneBarTests/      test runner executable
Resources/AppIcon.icns   app and disk-image icon
Scripts/                 tz table generator, .app and .dmg packaging
```

Replacing the icon is a matter of dropping a new `Resources/AppIcon.icns` in
place and rebuilding; both scripts pick it up, and both still work if it is
absent.

`ZoneBarCore` holds no UI, so everything that decides *what* is displayed is
covered by tests. The app shell only applies the result to AppKit objects.

Flags are Unicode emoji built from each zone's ISO 3166 country code — there are
no image assets. Zones with no country (UTC, GMT) show 🌐.

## Regenerating the time zone table

`Sources/ZoneBarCore/Generated/TimeZoneCountry.swift` is generated from the tz
database that ships with macOS. Refresh it after an OS tz update:

```bash
swift Scripts/generate_tz_table.swift
```

## Notes

- The app is menu-bar only (`LSUIElement`): no Dock icon, no app switcher entry.
- Preferences live in `UserDefaults` under `com.timeedit.zonebar`.
- `make_app.sh` signs ad-hoc, which is fine locally. Distributing to other
  machines needs a Developer ID identity and notarisation.
- `LSMinimumSystemVersion` is 14.0 because the Command Line Tools ship the
  macOS 14.4 SDK; the app runs fine on macOS 26 (Tahoe).
