/// <summary>
/// AetherOrbits.Scene.Renderer
/// Skia-based drawing of a TAetherScene (no simulation, no forms).
/// </summary>
///
/// <remarks>
/// Separation of concerns: reads scene state and paints into an ISkCanvas.
/// Safe to call from a paint-box OnDraw handler.
///
/// Skia is used here as an <b>open rendering API with efficient backends</b>
/// (raster / GPU paths under FMX), not as a game-loop black box. Frame timing
/// stays in AetherOrbits.GameLoop (ProcessAnimation / Display Link); this unit
/// only issues explicit draw calls when the UI asks for a repaint.
/// Orbit positions come from TAetherScene.GetOrbWorldPosition (single model).
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit AetherOrbits.Scene.Renderer;

interface

uses
  // System
  System.Types,
  System.UITypes,
  System.Math,
  // Skia
  System.Skia,
  // Own
  AetherOrbits.Scene;

type
  /// <summary>
  /// Renders a TAetherScene onto a Skia canvas.
  /// </summary>
  TAetherSceneRenderer = class sealed
  public
    /// <summary>
    /// Draws the full scene into ACanvas within ADest.
    /// </summary>
    class procedure Draw(
      const AScene: TAetherScene;
      const ACanvas: ISkCanvas;
      const ADest: TRectF); static;
  end;

implementation

const
  cCorePulseAmplitude = 0.08;
  cCorePulseFrequency = 1.7;
  cCoreOuterRadius = 95.0;
  cCoreMidRadius = 55.0;
  cCoreInnerRadius = 38.0;
  cGlowOuterScale = 2.8;
  cGlowMidScale = 1.7;
  cHighlightOffset = 0.25;
  cHighlightScale = 0.35;
  cHighlightAlpha = 0.55;
  cGlowOuterAlpha = 0.08;
  cGlowMidAlpha = 0.18;

class procedure TAetherSceneRenderer.Draw(
  const AScene: TAetherScene;
  const ACanvas: ISkCanvas;
  const ADest: TRectF);
var
  LPaint: ISkPaint;
  LOrb: TOrb;
  LOrbPos: TPointF;
  LParticles: TArray<TParticle>;
  LParticle: TParticle;
  LAlpha: Single;
  LRadius: Single;
  LCorePulse: Single;
  LCenter: TPointF;
  LColorRec: TAlphaColorRec;
  LCount: Integer;
begin
  if (AScene = nil) or (ACanvas = nil) then
  begin
    Exit;
  end;

  LCenter := AScene.Center;

  // Background
  LPaint := TSkPaint.Create;
  LPaint.Shader := TSkShader.MakeGradientRadial(
    ADest.CenterPoint,
    ADest.Width * 0.75,
    [$FF070B14, $FF0F1629, $FF1A243F]);
  ACanvas.DrawPaint(LPaint);

  // Central core
  LCorePulse := 1 + cCorePulseAmplitude * Sin(AScene.Time * cCorePulseFrequency);
  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;

  LPaint.Color := TAlphaColorF.Create(0.1, 0.4, 0.9, 0.12).ToAlphaColor;
  ACanvas.DrawCircle(LCenter.X, LCenter.Y, cCoreOuterRadius * LCorePulse, LPaint);

  LPaint.Color := TAlphaColorF.Create(0.2, 0.55, 1.0, 0.25).ToAlphaColor;
  ACanvas.DrawCircle(LCenter.X, LCenter.Y, cCoreMidRadius * LCorePulse, LPaint);

  LPaint.Shader := TSkShader.MakeGradientRadial(
    LCenter,
    cCoreInnerRadius * LCorePulse,
    [$FFFFFFFF, $FF66B3FF, $FF1A6BFF, $00000000]);
  ACanvas.DrawCircle(LCenter.X, LCenter.Y, cCoreInnerRadius * LCorePulse, LPaint);

  // Orbs — world position owned by the scene model
  for var i := 0 to AScene.OrbCount - 1 do
  begin
    LOrb := AScene.Orbs[i];
    LOrbPos := AScene.GetOrbWorldPosition(i);

    LPaint := TSkPaint.Create;
    LPaint.AntiAlias := True;
    LColorRec.Color := LOrb.Color;

    LPaint.Color := TAlphaColorF.Create(
      LColorRec.R / 255,
      LColorRec.G / 255,
      LColorRec.B / 255,
      cGlowOuterAlpha).ToAlphaColor;
    ACanvas.DrawCircle(LOrbPos.X, LOrbPos.Y, LOrb.Size * cGlowOuterScale, LPaint);

    LPaint.Color := TAlphaColorF.Create(
      LColorRec.R / 255,
      LColorRec.G / 255,
      LColorRec.B / 255,
      cGlowMidAlpha).ToAlphaColor;
    ACanvas.DrawCircle(LOrbPos.X, LOrbPos.Y, LOrb.Size * cGlowMidScale, LPaint);

    LPaint.Color := LOrb.Color;
    ACanvas.DrawCircle(LOrbPos.X, LOrbPos.Y, LOrb.Size, LPaint);

    LPaint.Color := TAlphaColorF.Create(1, 1, 1, cHighlightAlpha).ToAlphaColor;
    ACanvas.DrawCircle(
      LOrbPos.X - LOrb.Size * cHighlightOffset,
      LOrbPos.Y - LOrb.Size * cHighlightOffset,
      LOrb.Size * cHighlightScale,
      LPaint);
  end;

  // Particles — one array ref, iterate dense prefix only
  LParticles := AScene.Particles;
  LCount := AScene.ParticleCount;
  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;

  for var i := 0 to LCount - 1 do
  begin
    LParticle := LParticles[i];
    LAlpha := LParticle.Life / LParticle.MaxLife;
    LAlpha := LAlpha * LAlpha;
    LRadius := LParticle.Size * (0.6 + 0.4 * LAlpha);

    case Trunc(LParticle.Hue * 4) of
      0:
        LPaint.Color := TAlphaColorF.Create(0.3, 0.85, 1.0, LAlpha * 0.7).ToAlphaColor;
      1:
        LPaint.Color := TAlphaColorF.Create(1.0, 0.4, 0.75, LAlpha * 0.65).ToAlphaColor;
      2:
        LPaint.Color := TAlphaColorF.Create(1.0, 0.85, 0.4, LAlpha * 0.6).ToAlphaColor;
    else
      LPaint.Color := TAlphaColorF.Create(0.7, 0.55, 1.0, LAlpha * 0.65).ToAlphaColor;
    end;

    ACanvas.DrawCircle(LParticle.Position.X, LParticle.Position.Y, LRadius, LPaint);
  end;
end;

end.