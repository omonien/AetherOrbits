# FMX + Skia quirks (Delphi 13)

This document records platform and framework peculiarities we hit while building
**FireMonkey Animation Demos** (Aether Orbits, Helios). They matter when you mix **FireMonkey UI controls** with
**Skia** (especially Metal/GPU). They matter far less for a pure game-style
pipeline that draws everything itself into one surface.

## Scope: when this matters

| Pipeline | Why quirks appear |
|----------|-------------------|
| **Hybrid UI** (forms, labels, panels + Skia paint box) | FMX layout, styles, and Skia form canvas must composite together |
| **Self-rendered game view** (one full-window `TSkPaintBox` / surface, HUD drawn in Skia) | You own every pixel; FMX control compositing is largely out of the path |

The demos follow a **hybrid path that gradually moved toward
self-rendered HUD** for reliability under Metal. The game loop itself never
depended on these UI details.

---

## 1. `TAnimation` needs `Root` (Display Link)

**Symptom:** First paint looks fine, then the scene freezes.

**Cause:** `TAnimation.Start` only subscribes to the Display Link when
`Root <> nil`. Without a `Parent` in the FMX tree, FMX runs a one-shot
"immediate" animation and stops.

**Mitigation in this project:**

- `TGameLoop.Create` sets `Parent` when the owner is a `TFmxObject` (the form).
- `StartLoop` raises if `Root` is still nil.
- Call `StartLoop` from **OnShow** (form visible), not only from OnCreate.

Details: [`GameLoop.md`](GameLoop.md).

---

## 2. macOS: Skia Metal requires `GlobalUseMetal`

**Symptom:** Footer shows `Skia Raster (CPU)`, full-window particle scene ~single-digit FPS on Intel Mac (also via PAServer).

**Cause:** Embarcadero registers the Skia Metal canvas only when Metal is enabled:

```pascal
// FMX.Skia.Canvas.Metal.pas (simplified)
RegisterSkiaRenderCanvas(TMtlCanvas, True,
  function: Boolean
  begin
    Result := GlobalUseMetal;
  end);
```

And the default is:

```pascal
// FMX.Types.pas
GlobalUseMetal: Boolean = {$IFDEF IOS}True{$ELSE}False{$ENDIF};
```

So **iOS defaults to Metal; macOS does not.** Without `GlobalUseMetal := True`,
Skia falls back to **CPU raster**.

**Mitigation in `AetherOrbits.dpr`:**

```pascal
GlobalUseSkia := True;
GlobalUseSkiaRasterWhenAvailable := False;
{$IF Defined(MACOS) or Defined(IOS)}
GlobalUseMetal := True;
{$ENDIF}
```

Set these **before** `Application.Initialize`.

**Expected after fix:** footer backend like `Skia Metal (GPU) … Metal=on` and
much higher FPS.

---

## 3. Under Metal, FMX labels/panels can vanish over a full-client Skia surface

**Symptom:** After enabling Metal, the scene is smooth but a `TLabel` /
`TRectangle` stats bar at the bottom is **no longer visible**.

**Likely factors (observed in practice):**

- A client-aligned `TSkPaintBox` composites above or instead of sibling FMX
  controls when Skia is the form canvas.
- Styled FMX text controls may not repaint/composite reliably on the Metal path
  the same way they did with Skia Raster / classic FMX canvas.

**Mitigation in this project:** draw the stats **as a Skia overlay** inside
`TSkPaintBox.OnDraw` (same surface as the scene). No separate FMX chrome for
the HUD.

```
PaintBox.OnDraw
  ├── scene (upper rect)
  └── stats bar + text (bottom strip, DrawRect + DrawSimpleText)
```

### Why this is less important for "real" game rendering

A typical game (or game-like view) already:

1. Clears and draws the whole frame itself (`ISkCanvas` / engine renderer).
2. Draws HUD/debug text in the **same** pass.
3. Does **not** rely on `TLabel` / `TPanel` for runtime stats.

Those apps naturally avoid hybrid compositing bugs. This demo documented the
issue because we *did* start with hybrid FMX chrome for convenience, then moved
the footer onto Skia once Metal made the hybrid approach fragile.

**Rule of thumb:**

- **Debug/tools UI** (menus, dialogs): FMX controls are fine.
- **Per-frame game HUD / FPS**: draw with the game renderer (Skia), not with
  `TLabel` that must composite every frame on top of a full-window paint box.

---

## 4. Windows: same class of misconfiguration — raster preferred by default

**Symptom:** Workable but soft performance on a VM/desktop until flags are set;
footer shows `Skia Raster (CPU)`. After correct startup flags: e.g. **~60 FPS**
and `Skia OpenGL (GPU)` on the same Windows VM.

**Cause:** Enabling `GlobalUseSkia := True` alone is **not** full Skia setup.
On Windows, Embarcadero registers the raster canvas with **priority** when
`GlobalUseSkiaRasterWhenAvailable` is True (the default):

```pascal
// FMX.Skia.Canvas.pas (simplified)
RegisterSkiaRenderCanvas(TSkRasterCanvas,
  {$IF DEFINED(MSWINDOWS)}GlobalUseSkiaRasterWhenAvailable{$ELSE}False{$ENDIF});
```

So the defaults effectively say:

| Platform | Default that steers you to CPU raster |
|----------|----------------------------------------|
| **Windows** | `GlobalUseSkiaRasterWhenAvailable = True` (raster preferred) |
| **macOS** | `GlobalUseMetal = False` (Metal canvas not offered) |

Both are "Skia is on, but not the GPU path you expected." The footer is how we
noticed: first Mac ~6 FPS Raster, then Windows 60 FPS **OpenGL** only after
`PreferRaster` was turned off.

**Mitigation in this project:**

```pascal
GlobalUseSkia := True;
GlobalUseSkiaRasterWhenAvailable := False; // allow GL/Vulkan when registered
```

Optional later: `GlobalUseVulkan := True` on Windows/Android if you want Vulkan
instead of OpenGL (see Skia4Delphi / RAD docs). This demo does not force Vulkan.

**Takeaway:** Always **read back** the active canvas class (as the stats footer
does). `GlobalUseSkia` alone is not a performance guarantee.

---

## 5. How we report the active backend

`AetherOrbits.RuntimeInfo` reads:

1. `DefaultSkiaRenderCanvasClass` (Skia registration result), else  
2. `TCanvasManager.DefaultCanvas`

and maps class names to friendly labels (`Skia Raster (CPU)`, `Skia Metal (GPU)`, …).
Optional flags (`Metal=on`, `PreferRaster`) help confirm startup globals.

This is diagnostics for the **form canvas / Skia registration**, not a second
game engine.

---

## Checklist (copy into other FMX + Skia projects)

1. [ ] `GlobalUseSkia := True` before `Application.Initialize`
2. [ ] macOS/iOS: `GlobalUseMetal := True` if you want GPU Skia
3. [ ] Windows: `GlobalUseSkiaRasterWhenAvailable := False` (default True prefers CPU raster)
4. [ ] `TAnimation` / game loop: set `Parent` so `Root <> nil`; start when visible
5. [ ] Per-frame HUD: prefer Skia (or your engine) text, not FMX labels over a full paint box
6. [ ] Log or show active canvas class once at startup (as this demo does)

---

## Related files

| File | Role |
|------|------|
| [`src/AetherOrbits/AetherOrbits.dpr`](../src/AetherOrbits/AetherOrbits.dpr) | Startup globals (Skia / Metal / raster preference) |
| [`src/FMXAnimation.GameLoop.pas`](../src/FMXAnimation.GameLoop.pas) | Display Link loop + Root requirement (**shared**) |
| [`src/AetherOrbits/AetherOrbits.Main.Form.pas`](../src/AetherOrbits/AetherOrbits.Main.Form.pas) | Paint box + Skia stats overlay |
| [`src/FMXAnimation.SystemInfo.pas`](../src/FMXAnimation.SystemInfo.pas) | Platform / backend labels (**shared**) |
| [`GameLoop.md`](GameLoop.md) | Loop kernel deep-dive |

## 6. Multi-line HUD text: do not use `SplitString` with `sLineBreak`

`System.StrUtils.SplitString(S, Delimiters)` treats *each character* of
`Delimiters` as a separator. Passing `sLineBreak` (CR+LF on Windows) therefore
splits into three parts: `line1`, **empty**, `line2`. Drawing only indices
0 and 1 drops the platform/backend line and leaves a blank (dark) second row.

Use `TStringList.Text := S` or `S.Split([sLineBreak])` instead.