/// <summary>
/// AetherOrbits.Stats.Hud
/// Formats and draws the demo stats overlay (Skia). Uses SystemInfo for data.
/// </summary>
///
/// <remarks>
/// Presentation only. Adapts font size, line count, and bar height to surface
/// width (phone-friendly). System diagnostics live in AetherOrbits.SystemInfo.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit AetherOrbits.Stats.Hud;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Diagnostics,
  System.Math,
  System.Skia,
  AetherOrbits.SystemInfo;

/// <summary>
/// Height of the stats bar for a given surface width (responsive).
/// </summary>
function GetStatsHudHeight(const ASurfaceWidth: Single): Single;

type
  /// <summary>
  /// Rolling FPS / frame-time / CPU samples and multi-line HUD text.
  /// </summary>
  TStatsHudModel = record
  private
    FStopwatch: TStopwatch;
    FFrameCount: Integer;
    FWindowStart: Double;
    FLastRenderTime: Double;
    FFps: Integer;
    FFrameMs: Double;
    FRefreshTimer: Double;
    FPlatformLabel: string;
    FBackendLabel: string;
    FCpuPercentOfOneCore: Double;
    FLogicalCpuCount: Integer;
    FCpuSampler: TProcessCpuSampler;
    FText: string;
    FSurfaceWidth: Single;
  public
    procedure Reset;
    procedure CaptureEnvironment;
    procedure OnFrameRendered;
    function ShouldRefresh(const ADeltaTime: Double): Boolean;
    /// <summary>Rebuild text; ASurfaceWidth selects compact vs wide layout.</summary>
    procedure RefreshText(
      const AParticleCount, AOrbCount: Integer;
      const ASimTime: Double;
      const ASurfaceWidth: Single;
      const AParticleLabel: string = 'Particles';
      const AOrbLabel: string = 'Orbs');
    property Text: string read FText;
    property Fps: Integer read FFps;
    property FrameMs: Double read FFrameMs;
    property SurfaceWidth: Single read FSurfaceWidth;
  end;

  /// <summary>
  /// Draws the stats bar + text into a Skia canvas (bottom strip of ADest).
  /// </summary>
  TStatsHudPainter = class sealed
  public
    class procedure Draw(
      const ACanvas: ISkCanvas;
      const ADest: TRectF;
      const AText: string); static;
  end;

implementation

const
  cStatsRefreshInterval = 0.25;
  cStatsBarColor = $FF0B1220;
  cStatsTextColor = $FFE8EEF8;
  cStatsTextPadX = 10;
  cStatsPadTop = 12;
  cStatsLineStep = 14;
  cStatsPadBottom = 8;
  cNarrowWidth = 480;
  cMediumWidth = 720;

function IsNarrow(const AWidth: Single): Boolean;
begin
  Result := AWidth < cNarrowWidth;
end;

function IsMedium(const AWidth: Single): Boolean;
begin
  Result := (AWidth >= cNarrowWidth) and (AWidth < cMediumWidth);
end;

function FontSizeForWidth(const AWidth: Single): Single;
begin
  if IsNarrow(AWidth) then
    Result := 10
  else if IsMedium(AWidth) then
    Result := 11
  else
    Result := 12;
end;

function GetStatsHudHeight(const ASurfaceWidth: Single): Single;
begin
  // Narrow phones: 4 lines; medium: 3; wide: 2
  if IsNarrow(ASurfaceWidth) then
    Result := cStatsPadTop + 4 * cStatsLineStep + cStatsPadBottom
  else if IsMedium(ASurfaceWidth) then
    Result := cStatsPadTop + 3 * cStatsLineStep + cStatsPadBottom
  else
    Result := cStatsPadTop + 2 * cStatsLineStep + cStatsPadBottom;
end;

{ TStatsHudModel }

procedure TStatsHudModel.Reset;
begin
  FStopwatch := TStopwatch.StartNew;
  FFrameCount := 0;
  FWindowStart := 0;
  FLastRenderTime := 0;
  FFps := 0;
  FFrameMs := 0;
  FRefreshTimer := 0;
  FPlatformLabel := '';
  FBackendLabel := '';
  FCpuPercentOfOneCore := 0;
  FLogicalCpuCount := GetLogicalProcessorCount;
  FCpuSampler.Reset;
  FSurfaceWidth := 800;
  FText := 'FPS: -';
end;

procedure TStatsHudModel.CaptureEnvironment;
begin
  FPlatformLabel := GetHostPlatformLabel;
  FBackendLabel := GetActiveRenderBackendLabel;
end;

procedure TStatsHudModel.OnFrameRendered;
var
  LNow: Double;
begin
  LNow := FStopwatch.Elapsed.TotalSeconds;
  if FLastRenderTime > 0 then
  begin
    FFrameMs := (LNow - FLastRenderTime) * 1000.0;
  end;
  FLastRenderTime := LNow;

  Inc(FFrameCount);
  if (LNow - FWindowStart) >= 1.0 then
  begin
    FFps := FFrameCount;
    FFrameCount := 0;
    FWindowStart := LNow;
  end;
end;

function TStatsHudModel.ShouldRefresh(const ADeltaTime: Double): Boolean;
begin
  FRefreshTimer := FRefreshTimer + ADeltaTime;
  Result := FRefreshTimer >= cStatsRefreshInterval;
  if Result then
  begin
    FRefreshTimer := 0;
  end;
end;

procedure TStatsHudModel.RefreshText(
  const AParticleCount, AOrbCount: Integer;
  const ASimTime: Double;
  const ASurfaceWidth: Single;
  const AParticleLabel: string;
  const AOrbLabel: string);
var
  LOfMachine: Double;
  LLines: TStringList;
  LParticleLabel: string;
  LOrbLabel: string;
begin
  FSurfaceWidth := ASurfaceWidth;
  FCpuPercentOfOneCore := FCpuSampler.Sample;
  if FLogicalCpuCount < 1 then
  begin
    FLogicalCpuCount := 1;
  end;
  LOfMachine := FCpuPercentOfOneCore / FLogicalCpuCount;

  LParticleLabel := AParticleLabel;
  if LParticleLabel = '' then
  begin
    LParticleLabel := 'Particles';
  end;
  LOrbLabel := AOrbLabel;
  if LOrbLabel = '' then
  begin
    LOrbLabel := 'Orbs';
  end;

  LLines := TStringList.Create;
  try
    // Preferred is read live (radio can change it without re-CaptureEnvironment).
    if IsNarrow(ASurfaceWidth) then
    begin
      // Phone: short tokens, one topic per line
      LLines.Add(Format('FPS: %d  |  Frame: %.0f ms  |  Pref: %d',
        [FFps, FFrameMs, GetPreferredFramesPerSecond]));
      LLines.Add(Format('CPU: %.0f%%/core (%.0f%% of %d)  |  %s: %d  |  %s: %d',
        [FCpuPercentOfOneCore, LOfMachine, FLogicalCpuCount,
         LParticleLabel, AParticleCount, LOrbLabel, AOrbCount]));
      LLines.Add(Format('Sim: %.1fs  |  %s', [ASimTime, FPlatformLabel]));
      LLines.Add('Backend: ' + FBackendLabel);
    end
    else if IsMedium(ASurfaceWidth) then
    begin
      LLines.Add(Format('FPS: %d  |  Frame: %.1f ms  |  Preferred: %d  |  CPU: %.0f%% of 1 core (%.0f%% of %d)',
        [FFps, FFrameMs, GetPreferredFramesPerSecond, FCpuPercentOfOneCore, LOfMachine,
         FLogicalCpuCount]));
      LLines.Add(Format('%s: %d  |  %s: %d  |  Sim: %.1f s',
        [LParticleLabel, AParticleCount, LOrbLabel, AOrbCount, ASimTime]));
      LLines.Add(Format('Platform: %s  |  Backend: %s',
        [FPlatformLabel, FBackendLabel]));
    end
    else
    begin
      LLines.Add(Format(
        'FPS: %d  |  Frame: %.1f ms  |  Preferred: %d  |  CPU: %.0f%% of 1 core (%.0f%% of %d)  |  %s: %d  |  %s: %d  |  Sim: %.1f s',
        [FFps, FFrameMs, GetPreferredFramesPerSecond, FCpuPercentOfOneCore, LOfMachine,
         FLogicalCpuCount, LParticleLabel, AParticleCount, LOrbLabel, AOrbCount, ASimTime]));
      LLines.Add(Format('Platform: %s  |  Backend: %s',
        [FPlatformLabel, FBackendLabel]));
    end;
    FText := LLines.Text.Trim;
  finally
    LLines.Free;
  end;
end;

{ TStatsHudPainter }

class procedure TStatsHudPainter.Draw(
  const ACanvas: ISkCanvas;
  const ADest: TRectF;
  const AText: string);
var
  LBar: TRectF;
  LPaint: ISkPaint;
  LFont: ISkFont;
  LLines: TStringList;
  LHeight: Single;
  LFontSize: Single;
  LY: Single;
  i: Integer;
begin
  if ACanvas = nil then
  begin
    Exit;
  end;

  LHeight := GetStatsHudHeight(ADest.Width);
  LFontSize := FontSizeForWidth(ADest.Width);
  LBar := TRectF.Create(ADest.Left, ADest.Bottom - LHeight, ADest.Right, ADest.Bottom);

  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.Color := cStatsBarColor;
  ACanvas.DrawRect(LBar, LPaint);

  LLines := TStringList.Create;
  try
    LLines.Text := AText;
    LFont := TSkFont.Create(TSkTypeface.MakeDefault, LFontSize);
    LPaint.Color := cStatsTextColor;

    for i := 0 to LLines.Count - 1 do
    begin
      if LLines[i] = '' then
      begin
        Continue;
      end;
      LY := LBar.Top + cStatsPadTop + i * cStatsLineStep;
      LPaint.Color := cStatsTextColor;
      ACanvas.DrawSimpleText(
        LLines[i],
        LBar.Left + cStatsTextPadX,
        LY,
        LFont,
        LPaint);
    end;
  finally
    LLines.Free;
  end;
end;

end.