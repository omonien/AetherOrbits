# Aether Orbits

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Delphi](https://img.shields.io/badge/Delphi-13%20Florence-EE1F35.svg)](https://www.embarcadero.com/products/delphi)
[![FMX](https://img.shields.io/badge/FMX-FireMonkey-0D6EFD.svg)](https://docwiki.embarcadero.com/RADStudio/en/FireMonkey)
[![Skia](https://img.shields.io/badge/Skia-GPU%20%2F%20Metal%20%2F%20GL-26A69A.svg)](docs/FMX-Skia-Gotchas.md)
[![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20macOS%20%7C%20iOS-6C757D.svg)](#platforms--backends)
[![Game loop](https://img.shields.io/badge/game%20loop-Display%20Link-7B2CBF.svg)](docs/GameLoop.md)
[![GitHub release](https://img.shields.io/github/v/release/omonien/AetherOrbits?include_prereleases&label=release&color=success)](https://github.com/omonien/AetherOrbits/releases)
[![Stars](https://img.shields.io/github/stars/omonien/AetherOrbits?style=social)](https://github.com/omonien/AetherOrbits/stargazers)

A small **Delphi 13** FireMonkey demo: glowing orbs, particles, and a VSync-driven game loop — rendered with **Skia**, no third-party game engine.

---

## What you get when you run it

![Aether Orbits on Windows — Preferred FPS bar, particle scene, and stats footer](docs/images/aether-orbits-demo.png)

- An atmospheric particle field with orbiting orbs.
- A **dark stats footer**: FPS, frame time, process CPU, particle counts, platform, and active Skia/FMX backend.
- A **Preferred FPS** control (30 / 60 / 120) so you can see how the display link and pacing behave on your device.
- Smooth animation driven by FMX’s **Display Link** (Delphi 13), not a coarse `TTimer`.

Use it as a playable reference for “how do I do a clean frame loop + Skia drawing in FMX?”

---

## Quick start

### 1. Clone (with tests submodule)

```bash
git clone --recurse-submodules https://github.com/omonien/AetherOrbits.git
cd AetherOrbits
```

If you already cloned without submodules:

```bash
git submodule update --init --recursive
```

### 2. Open in the IDE

Open **`AetherOrbits.groupproj`** in RAD Studio / Delphi 13.

- App project: `src/AetherOrbits.dproj`
- Tests: `tests/AetherOrbits.Tests.dproj`

Select a platform (e.g. **Win64**, **OSX64**, **iOS Device 64-bit**) and run.

### 3. Command-line build (Windows)

```powershell
.\build-scripts\DelphiBuildDPROJ.ps1 -Project src\AetherOrbits.dproj -Platform Win64 -Config Debug
.\build-scripts\DelphiBuildDPROJ.ps1 -Project tests\AetherOrbits.Tests.dproj -Platform Win64 -Config Debug
.\build\Win64\Debug\AetherOrbits.Tests.exe
```

Output goes to `build/<Platform>/<Config>/` (git-ignored).

---

## Using the demo

| Control | Action |
|---------|--------|
| **Mouse / touch move** | Repels nearby particles (soft force field under the pointer) |
| **Click / tap** | Spawns a short particle burst at the pointer |
| **Preferred FPS** (top bar) | Request 30, 60, or 120 frames per second |
| **Stats footer** | Live FPS, frame ms, Preferred value, CPU, platform, render backend |

### Preferred FPS — what to expect

| Setting | Typical result |
|---------|----------------|
| **30** | ~30 FPS (paced; useful to save work or compare) |
| **60** | Default — matches most panels and FMX’s default preferred rate |
| **120** | Up to 120 only on ProMotion / 120 Hz displays; otherwise capped by the panel |

On **iPhone 16 (non-Pro)** the panel is **60 Hz** — choosing 120 will not go above ~60.  
On **Windows**, the OS display link often stays at monitor refresh; the demo **paces** the game loop so Preferred 30 still measures ~30 FPS in the footer.

---

## Platforms & backends

| Platform | Notes |
|----------|--------|
| **Windows 64** | Skia via OpenGL (or GPU path) when PreferRaster is off at startup |
| **macOS** | Metal enabled for Skia GPU (`GlobalUseMetal`) |
| **iOS** | Same Display Link / Metal path; responsive stats HUD for narrow screens |

The footer’s **Backend** line shows what is actually active (e.g. Skia Metal, Skia OpenGL, Skia Raster).

Startup flags that matter are set in `src/AetherOrbits.dpr` (Skia on; Windows PreferRaster off; Metal on for Apple). Details and pitfalls: **[docs/FMX-Skia-Gotchas.md](docs/FMX-Skia-Gotchas.md)**.

---

## Reuse the game loop in your own app

The frame clock is a **single, standalone unit** with no dependency on the demo scene or Skia:

**[`src/AetherOrbits.GameLoop.pas`](src/AetherOrbits.GameLoop.pas)**

1. Copy the unit into your FMX project.  
2. Create a `TGameLoop`, assign `OnUpdate` / `OnRender`.  
3. Call `StartLoop` when the form is shown (`Root` must be set — parent the loop to the form).

Deep dive: **[docs/GameLoop.md](docs/GameLoop.md)**  
(Display Link vs Preferred FPS vs fixed simulation timestep, Windows DWM pacing, etc.)

---

## Project layout

```
AetherOrbits/
├── src/                    # Demo app (GameLoop, Scene, Skia renderer, form, HUD)
├── tests/                  # DUnitX unit + form smoke tests
├── build-scripts/          # DelphiBuildDPROJ.ps1
├── docs/
│   ├── images/             # README screenshots
│   ├── GameLoop.md         # Loop design & FPS concepts
│   ├── FMX-Skia-Gotchas.md # Platform/Skia gotchas
│   └── Delphi Style Guide EN.md
├── libs/DUnitX/            # Git submodule
├── AetherOrbits.groupproj
├── LICENSE                 # MIT
└── README.md
```

### Architecture (short)

| Layer | Unit | Role |
|-------|------|------|
| Timing | `AetherOrbits.GameLoop` | Display Link + fixed timestep + Preferred pacing |
| Simulation | `AetherOrbits.Scene` | Orbs / particles — no UI, no Skia |
| Drawing | `AetherOrbits.Scene.Renderer` | Skia paint of scene state |
| Diagnostics | `AetherOrbits.SystemInfo` | Platform, backend, CPU samples |
| HUD | `AetherOrbits.Stats.Hud` | Footer text + Skia overlay |
| Shell | `AetherOrbits.Main.Form` | Form, Preferred bar, paint box wiring |

Skia draws pixels; it does **not** own the frame clock. The loop does not know about orbs or Skia.

---

## Requirements

- **Delphi 13** (Florence) or newer — Display Link–driven `TAnimation`
- **Integrated Skia** for the demo renderer (not required by `GameLoop` itself)
- **Git** with submodule support for DUnitX tests
- Optional: macOS / iOS deploy targets and signing as usual for FMX

---

## Documentation

| Doc | Audience |
|-----|----------|
| [docs/GameLoop.md](docs/GameLoop.md) | Reusing / understanding `TGameLoop` |
| [docs/FMX-Skia-Gotchas.md](docs/FMX-Skia-Gotchas.md) | Metal, PreferRaster, Root, HUD under Skia |
| [docs/Delphi Style Guide EN.md](docs/Delphi%20Style%20Guide%20EN.md) | Coding conventions used in this repo |

---

## License

Copyright © 2026 Olaf Monien. Released under the **[MIT License](LICENSE)**.
