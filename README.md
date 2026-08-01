# FireMonkey Animation Demos

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Delphi](https://img.shields.io/badge/Delphi-13%20Florence-EE1F35.svg)](https://www.embarcadero.com/products/delphi)
[![FMX](https://img.shields.io/badge/FMX-FireMonkey-0D6EFD.svg)](https://docwiki.embarcadero.com/RADStudio/en/FireMonkey)
[![Skia](https://img.shields.io/badge/Skia-GPU%20%2F%20Metal%20%2F%20GL-26A69A.svg)](docs/FMX-Skia-Gotchas.md)
[![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20macOS%20%7C%20iOS-6C757D.svg)](#platforms--backends)
[![Game loop](https://img.shields.io/badge/game%20loop-TAnimation%20%2B%20Display%20Link-7B2CBF.svg)](docs/GameLoop.md)
[![GitHub release](https://img.shields.io/github/v/release/omonien/AetherOrbits?include_prereleases&label=release&color=success)](https://github.com/omonien/AetherOrbits/releases)
[![Stars](https://img.shields.io/github/stars/omonien/AetherOrbits?style=social)](https://github.com/omonien/AetherOrbits/stargazers)

> **Repository:** still published as [`omonien/AetherOrbits`](https://github.com/omonien/AetherOrbits) (unchanged clone URL).  
> **Collection name:** **FireMonkey Animation Demos** — playable samples around one idea: smooth frame loops in Delphi 13.

---

## Why this exists

Since **Delphi 13**, FireMonkey drives `TAnimation` through the platform **Display Link** (VSync). That means you can build **buttery-smooth animation loops** — including for games — **out of the box**, without a third-party engine and without fighting a coarse `TTimer`.

This collection shows that path end-to-end:

| Piece | Role |
|-------|------|
| **`TGameLoop`** (`TAnimation` subclass) | The reusable frame clock — **copy one unit** into your own app |
| **Skia** | High-quality 2D / soft-3D drawing on GPU paths where available |
| **Demos** | Full apps that prove the loop feels right under real load |

No black-box game framework. The clock is FMX. The pixels are Skia. Your scene logic stays plain Delphi.

---

## The core unit: copy-and-go game loop

**[`src/FMXAnimation.GameLoop.pas`](src/FMXAnimation.GameLoop.pas)** is intentionally **demo-agnostic**:

- Depends only on `System.*` + `FMX.Types` / `FMX.Ani` (`TAnimation`)
- No forms, no Skia, no scene types
- Fixed timestep + optional Preferred-FPS pacing on top of Display Link

That is the **only** unit you need to copy for a VSync-aligned loop in your own app.

### Optional shared helpers (used by both demos)

| Unit | When you need it |
|------|------------------|
| [`FMXAnimation.SystemInfo`](src/FMXAnimation.SystemInfo.pas) | Platform / backend / CPU labels |
| [`FMXAnimation.Stats.Hud`](src/FMXAnimation.Stats.Hud.pas) | Skia stats footer overlay |
| [`FMXAnimation.DemoShell`](src/FMXAnimation.DemoShell.pas) | Client `TSkPaintBox`, HUD strip split, dark segment chrome, Preferred-FPS restart |

**To reuse the loop in your project:**

1. Copy `FMXAnimation.GameLoop.pas` into your FMX app.  
2. Create a `TGameLoop`, assign `OnUpdate` / `OnRender`.  
3. Call `StartLoop` when the form is shown (`Root` must be set — parent the loop to the form).  
4. *(Optional)* Copy `DemoShell` if you want the same paint-box / chrome patterns as the demos.

Deep dive: **[docs/GameLoop.md](docs/GameLoop.md)**  
(Display Link vs Preferred FPS vs fixed simulation timestep, Windows DWM pacing, pitfalls.)

### Code quickstart

```pascal
uses
  FMXAnimation.GameLoop;
  // Optional for demos-style UI:
  // FMXAnimation.DemoShell, FMXAnimation.Stats.Hud, FMXAnimation.SystemInfo

type
  TFormMain = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FGameLoop: TGameLoop;
    procedure DoUpdate(const ADeltaTime: Double);
    procedure DoRender;
  end;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  // Owner = form → Parent is set so Root <> nil (required for Display Link).
  FGameLoop := TGameLoop.Create(Self);
  FGameLoop.OnUpdate := DoUpdate;
  FGameLoop.OnRender := DoRender;
  // Optional: FGameLoop.FixedTimeStep := 1 / 60;  // simulation step only
end;

procedure TFormMain.FormShow(Sender: TObject);
begin
  // Start when visible — not only in OnCreate.
  if not FGameLoop.Running then
    FGameLoop.StartLoop;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  FGameLoop.StopLoop;
  // FGameLoop is owned by Self; no Free needed if Owner = Self
end;

procedure TFormMain.DoUpdate(const ADeltaTime: Double);
begin
  // Called 0..N times per display frame with a *fixed* step (default 1/60 s).
  // Advance the world here — not the pixels:
  //
  //   Player.X := Player.X + Player.SpeedX * ADeltaTime;
  //   ParticleSystem.Step(ADeltaTime);
  //
  // Keep this free of drawing code so the sim stays deterministic and testable.
end;

procedure TFormMain.DoRender;
begin
  // Called once per processed frame *after* updates. Only show the result:
  //
  //   PaintBox.Redraw;   // draw sprites / HUD / background from current state
  //
  // Do not advance physics here — that belongs in DoUpdate.
end;
```

**Pitfalls**

| Issue | Fix |
|-------|-----|
| Scene freezes after first frame | `Root` was nil — pass the form as `Owner` (or set `Parent`) and call `StartLoop` from **OnShow** |
| Preferred FPS 30 does nothing on Windows | Set `GlobalPreferredFramesPerSecond` (keep `PaceToPreferredFps` true — default); see [docs/GameLoop.md](docs/GameLoop.md) |
| Simulation too fast/slow | Change **`FixedTimeStep`**, not Preferred FPS |

---

## Demos

Two applications share the same loop + diagnostics. Each is a full FMX project under `src/`.

| Demo | Project | What it shows |
|------|---------|----------------|
| **Aether Orbits** | [`src/AetherOrbits/AetherOrbits.dproj`](src/AetherOrbits/AetherOrbits.dproj) | Particle field, glowing orbs, pointer forces, Preferred FPS |
| **Helios** | [`src/Helios/Helios.dproj`](src/Helios/Helios.dproj) | Soft-3D solar system, sim speed, pause, trails, click-to-focus |

![Aether Orbits on Windows — live demo: Preferred FPS bar, orbiting orbs, stats footer](docs/images/aether-orbits-demo.gif)

<sub>Aether Orbits · ≈8s capture · [MP4](docs/images/aether-orbits-demo.mp4) · [PNG](docs/images/aether-orbits-demo.png)</sub>

### Using Aether Orbits

| Control | Action |
|---------|--------|
| **Mouse / touch move** | Repels nearby particles (soft force field under the pointer) |
| **Click / tap** | Spawns a short particle burst at the pointer |
| **Preferred FPS** (top bar) | Request 30, 60, or 120 frames per second |
| **Stats footer** | Live FPS, frame ms, Preferred value, CPU, platform, render backend |

### Using Helios

| Control | Action |
|---------|--------|
| **Click / tap a body** | Smooth camera focus on that body + info panel |
| **Click empty space** / **Overview** | Reset camera to system overview |
| **Speed** (0.25× / 1× / 5× / 20×) | Simulation time scale |
| **Pause / Resume** | Freeze orbits (camera ease still runs) |
| **Trails** | Toggle orbital trail ribbons |
| **Preferred FPS** | Same Display Link pacing as Aether Orbits |
| **Stats footer** | FPS, frame ms, sim speed %, body count, platform, backend |

### Preferred FPS — what to expect

| Setting | Typical result |
|---------|----------------|
| **30** | ~30 FPS (paced; useful to save work or compare) |
| **60** | Default — matches most panels and FMX’s default preferred rate |
| **120** | Up to 120 only on ProMotion / 120 Hz displays; otherwise capped by the panel |

On **iPhone 16 (non-Pro)** the panel is **60 Hz** — choosing 120 will not go above ~60.  
On **Windows**, the OS display link often stays at monitor refresh; the demos **pace** the game loop so Preferred 30 still measures ~30 FPS in the footer.

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

Open **`AetherOrbits.groupproj`** in RAD Studio / Delphi 13 (project group for **FireMonkey Animation Demos**).

- Aether Orbits: `src/AetherOrbits/AetherOrbits.dproj`
- Helios: `src/Helios/Helios.dproj`
- Tests (both demos + shared units): `tests/AetherOrbits.Tests.dproj`

Select a platform (e.g. **Win64**, **OSX64**, **iOS Device 64-bit**) and run.

### 3. Command-line build (Windows)

```powershell
.\build-scripts\DelphiBuildDPROJ.ps1 -Project src\AetherOrbits\AetherOrbits.dproj -Platform Win64 -Config Debug
.\build-scripts\DelphiBuildDPROJ.ps1 -Project src\Helios\Helios.dproj -Platform Win64 -Config Debug
.\build-scripts\DelphiBuildDPROJ.ps1 -Project tests\AetherOrbits.Tests.dproj -Platform Win64 -Config Debug
.\build\Win64\Debug\AetherOrbits.Tests.exe
```

Output goes to `build/<Platform>/<Config>/` (git-ignored).

---

## Platforms & backends

| Platform | Notes |
|----------|--------|
| **Windows 64** | Skia via OpenGL (or GPU path) when PreferRaster is off at startup |
| **macOS** | Metal enabled for Skia GPU (`GlobalUseMetal`) |
| **iOS** | Same Display Link / Metal path; responsive stats HUD for narrow screens |

The footer’s **Backend** line shows what is actually active (e.g. Skia Metal, Skia OpenGL, Skia Raster).

Startup flags that matter are set in each demo’s `.dpr` (Skia on; Windows PreferRaster off; Metal on for Apple). Details: **[docs/FMX-Skia-Gotchas.md](docs/FMX-Skia-Gotchas.md)**.

---

## Project layout

```
AetherOrbits/                       # GitHub repo name (stable URL)
├── src/
│   ├── FMXAnimation.GameLoop.pas   # ★ shared frame loop — copy this
│   ├── FMXAnimation.SystemInfo.pas # shared diagnostics
│   ├── FMXAnimation.Stats.Hud.pas  # shared stats overlay
│   ├── FMXAnimation.DemoShell.pas  # shared paint-box / chrome helpers
│   ├── AetherOrbits/               # demo: orbs + particles
│   └── Helios/                     # demo: solar system
├── tests/                          # DUnitX (shared + both demos)
├── build-scripts/
├── docs/
│   ├── GameLoop.md                 # loop design & FPS concepts
│   ├── FMX-Skia-Gotchas.md
│   └── images/
├── libs/DUnitX/                    # Git submodule
├── AetherOrbits.groupproj
├── LICENSE                         # MIT
└── README.md
```

### Architecture (short)

Separation of concerns is intentional — each layer has one job:

```
TGameLoop (Display Link)          ← frame clock only
    │ OnUpdate → *.Scene.Update   ← simulation / world state (no Skia)
    │ OnRender → PaintBox.Redraw
    └─ OnDraw  → *.Scene.Renderer ← Skia paint of current state
               → Stats.Hud        ← diagnostics strip
Main.Form                         ← FMX controls + wiring only
DemoShell                         ← optional shared surface/chrome helpers
```

| Layer | Unit | Role |
|-------|------|------|
| Timing | `src/FMXAnimation.GameLoop` | Display Link + fixed timestep + Preferred pacing (**shared, copyable**) |
| Diagnostics | `src/FMXAnimation.SystemInfo` | Platform, backend, CPU samples (**shared**) |
| HUD | `src/FMXAnimation.Stats.Hud` | Footer text + Skia overlay (**shared**) |
| Demo shell | `src/FMXAnimation.DemoShell` | Paint box setup, HUD strip split, dark chip chrome (**shared**) |
| Simulation | `AetherOrbits.Scene` / `Helios.Scene` | Demo state — no UI, no Skia |
| Drawing | `*.Scene.Renderer` | Skia paint of scene state |
| Form UI | `*.Main.Form` | Form events, demo-specific controls, scene wiring |

Skia draws pixels; it does **not** own the frame clock. The loop does not know about orbs, planets, or Skia.

---

## Requirements

- **Delphi 13** (Florence) or newer — Display Link–driven `TAnimation`
- **Integrated Skia** for the demo renderers (not required by `GameLoop` itself)
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
