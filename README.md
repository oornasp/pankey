# Pankey

Native macOS Vietnamese IME with Telex/VNI, per-app exclusion, and 8-bit pixel UI.

**Status:** Phase 1 complete — project skeleton. See [plan](plans/260411-1742-pankey-vietnamese-ime/plan.md) for roadmap.

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ (required to build `PankeyMac.app`)
- Swift 5.9+ (included with Xcode 15)

## Project Structure

```
pankey/
├── Pankey.xcodeproj/          # Xcode project — open this in Xcode
├── PankeyCore/                # Swift Package: Vietnamese composition engine
│   ├── Package.swift
│   ├── Sources/PankeyCore/    # Engine implementation (Phase 2)
│   └── Tests/PankeyCoreTests/ # Unit tests (Phase 7)
├── PankeyMac/                 # macOS IME .app target
│   ├── main.swift
│   ├── AppDelegate.swift
│   ├── Info.plist             # IME registration keys
│   ├── PankeyMac.entitlements # Empty — no sandbox (required for IMK)
│   └── Resources/             # Place PressStart2P-Regular.ttf here
├── plans/                     # Implementation plans
└── docs/                      # Project documentation
```

## Build

### PankeyCore only (no Xcode required)

```bash
cd PankeyCore && swift build
cd PankeyCore && swift test
```

### Full app (requires Xcode)

```bash
# Install Xcode from the Mac App Store, then:
xcodebuild -project Pankey.xcodeproj -scheme PankeyMac -configuration Debug build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO
```

### Font setup (required for pixel UI — Phase 5)

1. Download `PressStart2P-Regular.ttf` from [fonts.google.com/specimen/Press+Start+2P](https://fonts.google.com/specimen/Press+Start+2P) (OFL 1.1 license)
2. Place it in `PankeyMac/Resources/`
3. In Xcode: Add to target PankeyMac → verify `ATSApplicationFontsPath` in Info.plist

## Install (development)

After building, copy `PankeyMac.app` to `~/Library/Input Methods/`, then log out and back in. Enable Pankey in **System Settings → Keyboard → Input Sources**.

## License

MIT — see [LICENSE](LICENSE)
