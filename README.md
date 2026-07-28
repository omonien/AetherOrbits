# Aether Orbits

FMX + Skia game-loop demo for **Delphi 13+**.

High-quality atmospheric demo that shows how to run a modern, VSync-synchronized
game loop under **FireMonkey + Skia** — **without third-party libraries**.

## Architecture (SoC)

| Layer | Unit | Responsibility |
|-------|------|----------------|
| Timing | `AetherOrbits.GameLoop` | VSync loop via `TAnimation` / Display Link, fixed timestep |
| Simulation | `AetherOrbits.Scene` | Orbs, particles, mouse forces — **no UI, no Skia** |
| Rendering | `AetherOrbits.Scene.Renderer` | Skia draw of scene state — **no simulation** |
| UI shell | `AetherOrbits.Main.Form` | Form + paint box; wires loop ↔ scene ↔ redraw |

## The core idea

**`src/AetherOrbits.GameLoop.pas`** derives from `TAnimation` and overrides
`ProcessAnimation`. The loop is driven by the **Display Link Service** (Delphi 13)
— i.e. directly by VSync / the display refresh rate.

## Project layout

```
AetherOrbits/
├── src/
│   ├── AetherOrbits.dpr / .dproj
│   ├── AetherOrbits.GameLoop.pas
│   ├── AetherOrbits.Scene.pas
│   ├── AetherOrbits.Scene.Renderer.pas
│   └── AetherOrbits.Main.Form.pas / .fmx
├── tests/                          # DUnitX (loop + scene + form smoke)
├── build/                          # Output (git-ignored)
├── build-scripts/DelphiBuildDPROJ.ps1
├── libs/DUnitX/                    # Git submodule
├── docs/Delphi Style Guide EN.md
├── AetherOrbits.groupproj
└── LICENSE                         # MIT
```

## Requirements

- Delphi 13 Florence (or newer)
- Integrated Skia
- Windows 64-bit (default; Win32 also enabled)

## Build

```powershell
.\build-scripts\DelphiBuildDPROJ.ps1 -ProjectFile "src\AetherOrbits.dproj" -Platform Win64 -Config Debug
.\build-scripts\DelphiBuildDPROJ.ps1 -ProjectFile "tests\AetherOrbits.Tests.dproj" -Platform Win64 -Config Debug
.\build\Win64\Debug\AetherOrbits.Tests.exe
```

Or open `AetherOrbits.groupproj` in the IDE.

## License

MIT — see [LICENSE](LICENSE).