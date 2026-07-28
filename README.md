# Aether Orbits

FMX + Skia game-loop demo for **Delphi 13+**.

High-quality atmospheric demo that shows how to run a modern, VSync-synchronized
game loop under **FireMonkey + Skia** — **without third-party libraries**.

## The core idea

The important unit is:

**`src/AetherOrbits.GameLoop.pas`**

It derives from `TAnimation` and overrides `ProcessAnimation`. The loop is then
driven by the **Display Link Service** (Delphi 13) — i.e. directly by VSync /
the display refresh rate.

That is the clean, framework-native way to implement game loops under FMX.

## Project layout

```
AetherOrbits/
├── src/
│   ├── AetherOrbits.dpr              # Application entry
│   ├── AetherOrbits.dproj
│   ├── AetherOrbits.GameLoop.pas     # ★ Isolated game-loop core
│   ├── AetherOrbits.Main.Form.pas    # Demo scene (orbs + particles)
│   └── AetherOrbits.Main.Form.fmx
├── tests/
│   ├── AetherOrbits.Tests.dpr        # DUnitX runner
│   ├── AetherOrbits.Tests.dproj
│   ├── AetherOrbits.GameLoop.Tests.pas
│   └── AetherOrbits.Main.Form.Smoke.pas
├── build/                            # Output (git-ignored)
├── build-scripts/
│   └── DelphiBuildDPROJ.ps1
├── libs/
│   └── DUnitX/                       # Git submodule
├── AetherOrbits.groupproj
├── LICENSE                           # MIT
└── README.md
```

## Requirements

- Delphi 13 Florence (or newer)
- Integrated Skia (ships with modern Delphi)
- Windows 64-bit (default target; Win32 also enabled)

## Build

```powershell
# App
.\build-scripts\DelphiBuildDPROJ.ps1 -ProjectFile "src\AetherOrbits.dproj" -Platform Win64 -Config Debug

# Tests
.\build-scripts\DelphiBuildDPROJ.ps1 -ProjectFile "tests\AetherOrbits.Tests.dproj" -Platform Win64 -Config Debug
.\build\Win64\Debug\AetherOrbits.Tests.exe
```

Or open `AetherOrbits.groupproj` in the IDE.

## Usage notes

- The demo is fully procedural (no external image assets).
- Mouse movement gently influences particles.
- Fixed timestep (1/60) + DisplayLink rendering.
- `AetherOrbits.GameLoop` is generic and can be copied into other projects as-is.
- `GlobalUseSkia := True` is set in the program entry point.

## License

MIT — see [LICENSE](LICENSE).