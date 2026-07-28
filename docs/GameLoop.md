# AetherOrbits.GameLoop — standalone FMX game loop (Delphi 13+)

## Independence

`AetherOrbits.GameLoop.pas` is intentionally **demo-agnostic**:

- **Uses:** `System.Classes`, `System.Diagnostics`, `System.SysUtils`, `FMX.Types`, `FMX.Ani`
- **Does not use:** forms, **Skia**, scene types, or any Aether Orbits–specific code

Copy the unit into another FMX project, create a `TGameLoop`, assign `OnUpdate` /
`OnRender`, call `StartLoop`. No other unit from this repository is required.

## Core idea: override `ProcessAnimation`

```pascal
TGameLoop = class(TAnimation)
protected
  procedure ProcessAnimation; override;  // ← the whole point
end;
```

### Why this is the Embarcadero / FMX approach on Delphi 13

In Delphi 13, FireMonkey animations are advanced by the platform **Display Link
Service**. That service is tied to the **display refresh (VSync)**. For each
active `TAnimation`, FMX invokes `ProcessAnimation` on those ticks.

Therefore:

- You do **not** invent your own frame clock.
- You plug into the **same pipeline** FMX already uses for property animations.
- You get **VSync-aligned** callbacks without third-party libraries.

| Hook | Role |
|------|------|
| `TAnimation.ProcessAnimation` | Framework entry point (Display Link) — **required core** |
| Fixed timestep + accumulator | Portable game-loop math **inside** that entry point |
| `OnUpdate` / `OnRender` | Consumer callbacks — no knowledge of scene/UI in the loop |

### What this unit adds on top of the override

1. High-resolution timing (`TStopwatch`) for real frame delta  
2. Max-frame clamp (debugger / Alt-Tab spiral-of-death guard)  
3. Fixed timestep updates (Glenn Fiedler pattern)  
4. One render/invalidate notification per display tick  

If you only remember one line from this project: **the kernel is the
`ProcessAnimation` override on a `TAnimation` subclass under Delphi 13’s
Display Link.**

## Skia is not the game loop

This repository’s demo **does** use Skia (see the main [README](../README.md)
section *Where Skia fits*), but only for **drawing**:

- Skia is **not** a black-box game engine that replaces `TGameLoop`.
- Skia does **not** own the frame clock; Display Link / `ProcessAnimation` does.
- Skia **does** give you access to **efficient rendering backends** (CPU raster,
  GPU paths where available) through an explicit canvas API (`ISkCanvas`, paints,
  shaders).

`OnRender` in this unit is deliberately abstract — typically “invalidate a
surface”. Whether that surface is painted with Skia, the classic FMX canvas, or
something else is the consumer’s choice and stays outside this unit.

## FMX pitfall: `Root` and when to start

`TAnimation.Start` (FMX.Ani) only subscribes to the **Display Link** when:

1. `Root <> nil` (animation is in the FMX object tree — set `Parent` to the form), and  
2. Duration is not treated as “immediate”, and  
3. If `Parent` is an `IControl`, that control is **Visible**.

If `Root = nil`, FMX runs a **one-shot immediate** animation (`ProcessAnimation` once) and sets `Running := False`. Symptom: first paint looks correct, then everything freezes.

`TGameLoop.Create` parents itself to the owner when the owner is a `TFmxObject`. Call `StartLoop` from **OnShow** (or after the form is visible), not only from OnCreate.

`StartLoop` raises `EInvalidOpException` if `Root` is still nil — fail loud instead of a silent freeze.