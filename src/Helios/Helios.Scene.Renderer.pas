/// <summary>
/// Helios.Scene.Renderer
/// Skia drawing of a THeliosScene (perspective projection, trails, labels, info).
/// </summary>
///
/// <remarks>
/// Reads scene state only. Frame timing stays in AetherOrbits.GameLoop.
/// Bodies are sorted back-to-front for a simple painter's algorithm.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit Helios.Scene.Renderer;

interface

uses
  System.Types,
  System.UITypes,
  System.SysUtils,
  System.Math,
  System.Skia,
  Helios.Scene;

type
  /// <summary>Renders THeliosScene onto an ISkCanvas.</summary>
  THeliosSceneRenderer = class sealed
  public
    class procedure Draw(
      const AScene: THeliosScene;
      const ACanvas: ISkCanvas;
      const ADest: TRectF); static;
  end;

implementation

type
  TDrawItem = record
    Index: Integer;
    Depth: Single;
    Screen: TPointF;
    Radius: Single;
    Visible: Boolean;
  end;

const
  cStarCount = 120;
  cOrbitRingAlpha = 0.10;
  cTrailAlpha = 0.55;
  cLabelColor = $FFC8D4E8;
  cInfoPanelBg = $E0101828;
  cInfoPanelStroke = $FF2A3A50;
  cInfoTitleColor = $FFE8EEF8;
  cInfoMutedColor = $FF8B9BB4;
  cFocusRingColor = $FF5B9BD5;

class procedure THeliosSceneRenderer.Draw(
  const AScene: THeliosScene;
  const ACanvas: ISkCanvas;
  const ADest: TRectF);
var
  LPaint: ISkPaint;
  LFont: ISkFont;
  LFontSmall: ISkFont;
  LItems: TArray<TDrawItem>;
  LBody: TBody;
  LTrail: TOrbitTrail;
  LColorRec: TAlphaColorRec;
  LScreen: TPointF;
  LDepth: Single;
  LPrev: TPointF;
  LHasPrev: Boolean;
  LAlpha: Single;
  LPanel: TRectF;
  LFocused: Integer;
  i, j: Integer;
  LTmp: TDrawItem;
  LSeed: Integer;
  LStarX, LStarY, LStarA: Single;
  LOrbitPt: TVec3;
  LAngle: Single;
  LOrbitSteps: Integer;
  LCosI, LSinI: Single;
begin
  if (AScene = nil) or (ACanvas = nil) or (not AScene.Initialized) then
  begin
    Exit;
  end;

  // Deep space background
  LPaint := TSkPaint.Create;
  LPaint.Shader := TSkShader.MakeGradientRadial(
    ADest.CenterPoint,
    ADest.Width * 0.85,
    [$FF04060C, $FF0A1020, $FF121C32]);
  ACanvas.DrawPaint(LPaint);

  // Stable pseudo-random starfield from viewport size (no allocations / flicker).
  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;
  LSeed := Trunc(ADest.Width * 13 + ADest.Height * 7);
  for i := 0 to cStarCount - 1 do
  begin
    LSeed := LSeed * 1103515245 + 12345;
    LStarX := ADest.Left + (Abs(LSeed) mod 10000) / 10000.0 * ADest.Width;
    LSeed := LSeed * 1103515245 + 12345;
    LStarY := ADest.Top + (Abs(LSeed) mod 10000) / 10000.0 * ADest.Height;
    LSeed := LSeed * 1103515245 + 12345;
    LStarA := 0.25 + (Abs(LSeed) mod 1000) / 1000.0 * 0.55;
    LPaint.Color := TAlphaColorF.Create(0.85, 0.9, 1.0, LStarA).ToAlphaColor;
    ACanvas.DrawCircle(LStarX, LStarY, 0.6 + (i mod 3) * 0.35, LPaint);
  end;

  // Orbital guide rings (faint ellipses via sampled world points)
  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;
  LPaint.Style := TSkPaintStyle.Stroke;
  LPaint.StrokeWidth := 1;
  LOrbitSteps := 64;
  for i := 1 to AScene.BodyCount - 1 do
  begin
    LBody := AScene.Bodies[i];
    LCosI := Cos(LBody.Inclination);
    LSinI := Sin(LBody.Inclination);
    LColorRec.Color := LBody.Color;
    LPaint.Color := TAlphaColorF.Create(
      LColorRec.R / 255, LColorRec.G / 255, LColorRec.B / 255, cOrbitRingAlpha).ToAlphaColor;

    LHasPrev := False;
    LPrev := TPointF.Zero;
    for j := 0 to LOrbitSteps do
    begin
      LAngle := j / LOrbitSteps * Pi * 2;
      LOrbitPt := TVec3.Create(
        Cos(LAngle) * LBody.OrbitRadius,
        Sin(LAngle) * LBody.OrbitRadius * LSinI,
        Sin(LAngle) * LBody.OrbitRadius * LCosI);
      if AScene.ProjectPoint(LOrbitPt, ADest, LScreen, LDepth) then
      begin
        if LHasPrev then
        begin
          ACanvas.DrawLine(LPrev.X, LPrev.Y, LScreen.X, LScreen.Y, LPaint);
        end;
        LPrev := LScreen;
        LHasPrev := True;
      end
      else
      begin
        LHasPrev := False;
      end;
    end;
  end;

  // Orbital trails
  if AScene.ShowTrails then
  begin
    LPaint := TSkPaint.Create;
    LPaint.AntiAlias := True;
    LPaint.Style := TSkPaintStyle.Stroke;
    LPaint.StrokeWidth := 1.5;
    LPaint.StrokeCap := TSkStrokeCap.Round;

    for i := 1 to AScene.BodyCount - 1 do
    begin
      LTrail := AScene.Trails[i];
      if LTrail.Count < 2 then
      begin
        Continue;
      end;
      LBody := AScene.Bodies[i];
      LColorRec.Color := LBody.Color;
      LHasPrev := False;
      LPrev := TPointF.Zero;
      for j := 0 to LTrail.Count - 1 do
      begin
        if not AScene.ProjectPoint(LTrail.GetPoint(j), ADest, LScreen, LDepth) then
        begin
          LHasPrev := False;
          Continue;
        end;
        LAlpha := (j + 1) / LTrail.Count * cTrailAlpha;
        LPaint.Color := TAlphaColorF.Create(
          LColorRec.R / 255, LColorRec.G / 255, LColorRec.B / 255, LAlpha).ToAlphaColor;
        if LHasPrev then
        begin
          ACanvas.DrawLine(LPrev.X, LPrev.Y, LScreen.X, LScreen.Y, LPaint);
        end;
        LPrev := LScreen;
        LHasPrev := True;
      end;
    end;
  end;

  // Project + sort bodies by depth (far first)
  SetLength(LItems, AScene.BodyCount);
  for i := 0 to AScene.BodyCount - 1 do
  begin
    LItems[i].Index := i;
    LItems[i].Visible := AScene.ProjectPoint(
      AScene.Bodies[i].Position, ADest, LItems[i].Screen, LItems[i].Depth);
    LItems[i].Radius := AScene.ProjectedBodyRadius(i, ADest);
  end;
  for i := 0 to High(LItems) - 1 do
  begin
    for j := i + 1 to High(LItems) do
    begin
      if LItems[j].Depth > LItems[i].Depth then
      begin
        LTmp := LItems[i];
        LItems[i] := LItems[j];
        LItems[j] := LTmp;
      end;
    end;
  end;

  LFont := TSkFont.Create(TSkTypeface.MakeDefault, 12);
  LFontSmall := TSkFont.Create(TSkTypeface.MakeDefault, 10);
  LFocused := AScene.FocusedIndex;

  for i := 0 to High(LItems) do
  begin
    if not LItems[i].Visible then
    begin
      Continue;
    end;
    LBody := AScene.Bodies[LItems[i].Index];
    LColorRec.Color := LBody.Color;
    LScreen := LItems[i].Screen;
    LDepth := Max(0.15, 1 - LItems[i].Depth * 0.55);
    LAlpha := EnsureRange(LDepth, 0.35, 1.0);

    LPaint := TSkPaint.Create;
    LPaint.AntiAlias := True;
    LPaint.Style := TSkPaintStyle.Fill;

    // Soft glow
    LPaint.Color := TAlphaColorF.Create(
      LColorRec.R / 255, LColorRec.G / 255, LColorRec.B / 255, 0.10 * LAlpha).ToAlphaColor;
    ACanvas.DrawCircle(LScreen.X, LScreen.Y, LItems[i].Radius * 2.6, LPaint);

    LPaint.Color := TAlphaColorF.Create(
      LColorRec.R / 255, LColorRec.G / 255, LColorRec.B / 255, 0.22 * LAlpha).ToAlphaColor;
    ACanvas.DrawCircle(LScreen.X, LScreen.Y, LItems[i].Radius * 1.55, LPaint);

    // Body fill with simple radial shading
    LPaint.Shader := TSkShader.MakeGradientRadial(
      TPointF.Create(
        LScreen.X - LItems[i].Radius * 0.3,
        LScreen.Y - LItems[i].Radius * 0.3),
      LItems[i].Radius * 1.2,
      [
        TAlphaColorF.Create(1, 1, 1, 0.85 * LAlpha).ToAlphaColor,
        LBody.Color,
        TAlphaColorF.Create(
          LColorRec.R / 510, LColorRec.G / 510, LColorRec.B / 510, LAlpha).ToAlphaColor
      ]);
    ACanvas.DrawCircle(LScreen.X, LScreen.Y, LItems[i].Radius, LPaint);
    LPaint.Shader := nil;

    // Saturn-style ring (simple ellipse stroke)
    if SameText(LBody.Name, 'Saturn') then
    begin
      LPaint.Style := TSkPaintStyle.Stroke;
      LPaint.StrokeWidth := Max(1.0, LItems[i].Radius * 0.12);
      LPaint.Color := TAlphaColorF.Create(0.9, 0.85, 0.65, 0.55 * LAlpha).ToAlphaColor;
      ACanvas.DrawOval(
        TRectF.Create(
          LScreen.X - LItems[i].Radius * 1.9,
          LScreen.Y - LItems[i].Radius * 0.45,
          LScreen.X + LItems[i].Radius * 1.9,
          LScreen.Y + LItems[i].Radius * 0.45),
        LPaint);
      LPaint.Style := TSkPaintStyle.Fill;
    end;

    // Focus ring
    if LItems[i].Index = LFocused then
    begin
      LPaint.Style := TSkPaintStyle.Stroke;
      LPaint.StrokeWidth := 1.5;
      LPaint.Color := cFocusRingColor;
      ACanvas.DrawCircle(LScreen.X, LScreen.Y, LItems[i].Radius + 6, LPaint);
      LPaint.Style := TSkPaintStyle.Fill;
    end;

    // Labels
    if AScene.ShowLabels then
    begin
      LPaint.Color := cLabelColor;
      ACanvas.DrawSimpleText(
        LBody.Name,
        LScreen.X + LItems[i].Radius + 6,
        LScreen.Y - 2,
        LFontSmall,
        LPaint);
    end;
  end;

  // Info panel for focused body
  if (LFocused >= 0) and (LFocused < AScene.BodyCount) then
  begin
    LBody := AScene.Bodies[LFocused];
    LPanel := TRectF.Create(
      ADest.Right - 248,
      ADest.Top + 12,
      ADest.Right - 12,
      ADest.Top + 118);

    LPaint := TSkPaint.Create;
    LPaint.AntiAlias := True;
    LPaint.Style := TSkPaintStyle.Fill;
    LPaint.Color := cInfoPanelBg;
    ACanvas.DrawRoundRect(LPanel, 8, 8, LPaint);

    LPaint.Style := TSkPaintStyle.Stroke;
    LPaint.StrokeWidth := 1;
    LPaint.Color := cInfoPanelStroke;
    ACanvas.DrawRoundRect(LPanel, 8, 8, LPaint);

    LPaint.Style := TSkPaintStyle.Fill;
    LPaint.Color := cInfoTitleColor;
    ACanvas.DrawSimpleText(LBody.Name, LPanel.Left + 14, LPanel.Top + 22, LFont, LPaint);

    LPaint.Color := cInfoMutedColor;
    ACanvas.DrawSimpleText(
      'Distance  ' + LBody.DistanceLabel,
      LPanel.Left + 14, LPanel.Top + 44, LFontSmall, LPaint);
    ACanvas.DrawSimpleText(
      'Period    ' + LBody.PeriodLabel,
      LPanel.Left + 14, LPanel.Top + 62, LFontSmall, LPaint);
    ACanvas.DrawSimpleText(
      LBody.Fact,
      LPanel.Left + 14, LPanel.Top + 86, LFontSmall, LPaint);
  end
  else
  begin
    // Overview hint
    LPaint := TSkPaint.Create;
    LPaint.AntiAlias := True;
    LPaint.Color := cInfoMutedColor;
    ACanvas.DrawSimpleText(
      'Click a body to focus · Overview resets the camera',
      ADest.Left + 14,
      ADest.Top + 22,
      LFontSmall,
      LPaint);
  end;
end;

end.
