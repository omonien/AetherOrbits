# Aether Orbits

FMX + Skia demo for **Delphi 13+**: a VSync-driven game loop plus an atmospheric
scene drawn with Skia’s efficient rendering backends — **without third-party
game frameworks**.

## The core idea (standalone game loop)

The reusable kernel lives in a **single, independent unit**:

**[`src/AetherOrbits.GameLoop.pas`](src/AetherOrbits.GameLoop.pas)**

It has **no dependency** on the demo scene, Skia, or the main form — only on
`TAnimation` (`FMX.Ani`). You can copy that unit into any FMX project as-is.

See also [`docs/GameLoop.md`](docs/GameLoop.md).

### Why `ProcessAnimation` is the point

From **Delphi 13**, Embarcadero drives FMX animations through the platform
**Display Link Service** (display refresh / VSync). For every running
`TAnimation`, the framework calls the virtual method

```pascal
procedure ProcessAnimation; override;
```

on each display-link tick.

That is the **official, framework-native hook** for continuous per-frame work:

| Approach | Problem |
|----------|---------|
| `TTimer` | Coarse resolution, not VSync-aligned, drift |
| Background thread + `TThread.Queue` | Extra complexity, still need UI-thread paint |
| `Application.OnIdle` | Starves under load, not display-paced |
| **`TAnimation.ProcessAnimation` (D13)** | Inside FMX’s Display Link pipeline — VSync-paced, no third-party loop |

So the central idea of this project is deliberately small:

1. **Subclass `TAnimation`.**
2. **Override `ProcessAnimation`** — that is the integration point Embarcadero gives you.
3. Inside the override, apply a classic **fixed timestep** (update N times with a
   constant δt, render once per tick).

Everything else in the repo (orbs, particles, Skia) is only a **demo** of wiring
`OnUpdate` / `OnRender`. The loop unit does not know about any of it.

## Where Skia fits (and where it does not)

**Skia is the rendering layer of this demo — not the game loop.**

It is easy to treat “FMX + Skia” as a black box that somehow “does games for
you”. That is **not** how this project is structured:

| Concern | Who owns it | Skia involved? |
|---------|-------------|----------------|
| Frame clock / VSync | `TGameLoop` → `ProcessAnimation` (FMX Display Link) | **No** |
| Simulation / physics | `TAetherScene.Update` | **No** |
| Drawing commands | `TAetherSceneRenderer` → `ISkCanvas` / `ISkPaint` | **Yes** |
| GPU/CPU raster backend | Integrated Skia under FMX (`GlobalUseSkia`) | **Yes** (infrastructure) |

### Why use Skia then?

Skia (integrated in modern Delphi / FMX) is an **open, efficient 2D graphics
engine** with real rendering backends — not a closed game-loop product:

- **Backends** such as raster (CPU), OpenGL, Metal, Vulkan (platform-dependent)
  sit under the same Skia API (`ISkCanvas`, shaders, paints, paths).
- You issue **explicit draw calls** (circles, gradients, custom shaders) — full
  control over what is painted each frame.
- With `GlobalUseSkia := True`, FMX can route control painting through Skia’s
  pipeline, so the UI stack and custom paint boxes share the **same efficient
  backend** instead of the older FMX canvas path alone.
- Controls like `TSkPaintBox` expose an `OnDraw(… ISkCanvas …)` callback: you
  get a Skia canvas bound to the surface, not a hidden “engine tick”.

So in this demo:

1. **Display Link** decides *when* a frame happens (`ProcessAnimation`).
2. **Scene** decides *what* the world state is (`Update`).
3. **Skia** decides *how pixels are produced* (`Draw` on `ISkCanvas`) via its
   backends — transparent, replaceable drawing technology, **orthogonal** to the
   loop.

You could swap Skia for another painter and keep `TGameLoop` unchanged. You
could use Skia in a static form with no game loop. They compose; neither
absorbs the other.

## Architecture (SoC)

| Layer | Unit | Responsibility |
|-------|------|----------------|
| **Timing (standalone)** | `AetherOrbits.GameLoop` | VSync via `ProcessAnimation`; fixed timestep; callbacks only |
| Simulation | `AetherOrbits.Scene` | Orbs, particles, mouse forces — **no UI, no Skia** |
| Rendering | `AetherOrbits.Scene.Renderer` | Explicit Skia draw of scene state — **no simulation, no loop** |
| UI shell | `AetherOrbits.Main.Form` | Form + `TSkPaintBox`; wires loop ↔ scene ↔ redraw |

```
Display Link (FMX D13)
        │
        ▼
TGameLoop.ProcessAnimation   ◄── core override (no Skia)
        │
        ├── OnUpdate(δt)  →  TAetherScene.Update      (no Skia)
        └── OnRender      →  TSkPaintBox.Redraw
                                    │
                                    ▼ OnDraw
                         TAetherSceneRenderer.Draw
                         (ISkCanvas → Skia backends)
```

## Project layout

```
AetherOrbits/
├── src/
│   ├── AetherOrbits.dpr / .dproj
│   ├── AetherOrbits.GameLoop.pas      ★ standalone kernel (copy-friendly)
│   ├── AetherOrbits.Scene.pas
│   ├── AetherOrbits.Scene.Renderer.pas
│   └── AetherOrbits.Main.Form.pas / .fmx
├── tests/                          # DUnitX (loop + scene + form smoke)
├── build/                          # Output (git-ignored)
├── build-scripts/DelphiBuildDPROJ.ps1
├── libs/DUnitX/                    # Git submodule
├── docs/
│   ├── GameLoop.md                 # Loop kernel deep-dive
│   └── Delphi Style Guide EN.md
├── AetherOrbits.groupproj
└── LICENSE                         # MIT
```

## Requirements

- Delphi 13 Florence (or newer) — Display Link–driven `TAnimation`
- Integrated Skia — demo rendering / backends only; **not** required by `GameLoop`
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