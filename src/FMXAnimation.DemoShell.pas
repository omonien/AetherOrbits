/// <summary>
/// FMXAnimation.DemoShell
/// Small shared helpers for demo form shells (paint box, HUD strip, chrome).
/// </summary>
///
/// <remarks>
/// Keeps Main.Form units thin: scene logic stays in the demos; this unit only
/// generalizes the repeated FMX/Skia surface and dark toolbar chip styling.
/// Intentionally not a base form — demos keep their own FMX layouts and events.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit FMXAnimation.DemoShell;

interface

uses
  System.Types,
  System.UITypes,
  System.Classes,
  System.Math,
  FMX.Types,
  FMX.Controls,
  FMX.StdCtrls,
  FMX.Objects,
  FMX.Skia,
  FMXAnimation.GameLoop,
  FMXAnimation.Stats.Hud,
  FMXAnimation.SystemInfo;

const
  /// <summary>Dark chrome — matches the stats HUD bar.</summary>
  cDemoBarBg = $FF0B1220;
  cDemoBarLine = $FF1E2A3C;
  cDemoSegIdleFill = $FF151C2A;
  cDemoSegIdleStroke = $FF2A3A50;
  cDemoSegIdleText = $FF9AABC4;
  cDemoSegSelFill = $FF2563A8;
  cDemoSegSelStroke = $FF3B82C4;
  cDemoSegSelText = $FFE8EEF8;
  cDemoLabelMuted = $FF8B9BB4;
  cDemoHintMuted = $FF5C6B82;

/// <summary>
/// Client-aligned TSkPaintBox under AHost. Caller assigns OnDraw / mouse handlers.
/// Host HitTest is set False so the paint box receives pointer input.
/// </summary>
function CreateClientPaintBox(
  AOwner: TComponent;
  AHost: TFmxObject): TSkPaintBox;

/// <summary>
/// Scene height above the stats HUD strip for a surface of AWidth × AHeight.
/// </summary>
function GetSceneViewportHeight(const AWidth, AHeight: Single): Single;

/// <summary>
/// Local scene rect (0,0)–(Width, viewport height) for hit-tests and viewport setup.
/// </summary>
function GetSceneDrawRect(const AWidth, AHeight: Single): TRectF;

/// <summary>
/// Splits a paint-box OnDraw destination into the scene area (above the HUD strip).
/// </summary>
function GetSceneDestInPaintBox(const ADest: TRectF): TRectF;

/// <summary>
/// Styles a dark toolbar segment chip (rectangle + centered label).
/// </summary>
procedure StyleSegmentChip(
  const ARect: TRectangle;
  const ALabel: TLabel;
  const ASelected: Boolean);

/// <summary>
/// Drops family/style from styled settings and sets a fixed font color
/// so platform styles do not recolor demo chrome.
/// </summary>
procedure StyleDemoLabel(const ALabel: TLabel; const AColor: TAlphaColor);

/// <summary>
/// Sets GlobalPreferredFramesPerSecond and optionally restarts AGameLoop so
/// Mac/iOS CADisplayLink re-applies the preferred range. No-op when already set.
/// Returns True if the preferred value changed.
/// </summary>
function ApplyPreferredFps(
  const AFps: Integer;
  AGameLoop: TGameLoop;
  const ARestartLoop: Boolean;
  const AFormVisible: Boolean): Boolean;

implementation

function CreateClientPaintBox(
  AOwner: TComponent;
  AHost: TFmxObject): TSkPaintBox;
begin
  Result := TSkPaintBox.Create(AOwner);
  Result.Parent := AHost;
  Result.Align := TAlignLayout.Client;
  // HitTest must be True so pointer events hit the scene surface.
  Result.HitTest := True;
  Result.CanFocus := False;
  if AHost is TControl then
  begin
    TControl(AHost).HitTest := False;
  end;
end;

function GetSceneViewportHeight(const AWidth, AHeight: Single): Single;
begin
  Result := Max(1, AHeight - GetStatsHudHeight(AWidth));
end;

function GetSceneDrawRect(const AWidth, AHeight: Single): TRectF;
begin
  Result := TRectF.Create(0, 0, Max(1, AWidth), GetSceneViewportHeight(AWidth, AHeight));
end;

function GetSceneDestInPaintBox(const ADest: TRectF): TRectF;
begin
  Result := ADest;
  Result.Bottom := Max(ADest.Top + 1, ADest.Bottom - GetStatsHudHeight(ADest.Width));
end;

procedure StyleSegmentChip(
  const ARect: TRectangle;
  const ALabel: TLabel;
  const ASelected: Boolean);
begin
  if ASelected then
  begin
    ARect.Fill.Color := cDemoSegSelFill;
    ARect.Stroke.Color := cDemoSegSelStroke;
    ALabel.TextSettings.FontColor := cDemoSegSelText;
  end
  else
  begin
    ARect.Fill.Color := cDemoSegIdleFill;
    ARect.Stroke.Color := cDemoSegIdleStroke;
    ALabel.TextSettings.FontColor := cDemoSegIdleText;
  end;
end;

procedure StyleDemoLabel(const ALabel: TLabel; const AColor: TAlphaColor);
begin
  ALabel.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  ALabel.TextSettings.FontColor := AColor;
end;

function ApplyPreferredFps(
  const AFps: Integer;
  AGameLoop: TGameLoop;
  const ARestartLoop: Boolean;
  const AFormVisible: Boolean): Boolean;
var
  LWasRunning: Boolean;
begin
  Result := GetPreferredFramesPerSecond <> AFps;
  if not Result then
  begin
    Exit;
  end;

  SetPreferredFramesPerSecond(AFps);

  if ARestartLoop and Assigned(AGameLoop) then
  begin
    // Mac/iOS CADisplayLink applies preferred range on Subscribe — restart loop.
    // Windows DWM still needs GameLoop Preferred pacing (see FMXAnimation.GameLoop).
    LWasRunning := AGameLoop.Running;
    AGameLoop.StopLoop;
    if LWasRunning or AFormVisible then
    begin
      AGameLoop.StartLoop;
    end;
  end;
end;

end.
