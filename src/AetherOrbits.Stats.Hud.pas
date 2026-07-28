/// <summary>
/// AetherOrbits.Stats.Hud
/// Formats and draws the demo stats overlay (Skia). Uses SystemInfo for data.
/// </summary>
///
/// <remarks>
/// Presentation only. Platform/backend/CPU sampling live in AetherOrbits.SystemInfo.
/// Drawn as a Skia overlay so the HUD stays visible under Metal.
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

const
  /// <summary>Height reserved for the stats bar (layout + overlay).</summary>
  cStatsHudHeight = 44;

type
  /// <summary>
  /// Rolling FPS / frame-time / CPU samples and formatted two-line text.
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
  public
    procedure Reset;
    /// <summary>Capture platform + backend once after app/canvas init.</summary>
    procedure CaptureEnvironment;
    procedure OnFrameRendered;
    function ShouldRefresh(const ADeltaTime: Double): Boolean;
    procedure RefreshText(
      const AParticleCount, AOrbCount: Integer;
      const ASimTime: Double);
    property Text: string read FText;
    property Fps: Integer read FFps;
    property FrameMs: Double read FFrameMs;
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
  cStatsFontSize = 12;
  cStatsTextPadX = 12;
  cStatsLine1Y = 16;
  cStatsLine2Y = 34;
  scStatsFormat =
    'FPS: %d  |  Frame: %.1f ms  |  CPU: %.0f%% of 1 core (%.0f%% of %d)  |  Particles: %d  |  Orbs: %d  |  Sim: %.1f s' + sLineBreak +
    'Platform: %s  |  Backend: %s';

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
  const ASimTime: Double);
var
  LOfMachine: Double;
begin
  FCpuPercentOfOneCore := FCpuSampler.Sample;
  if FLogicalCpuCount < 1 then
  begin
    FLogicalCpuCount := 1;
  end;
  LOfMachine := FCpuPercentOfOneCore / FLogicalCpuCount;

  FText := Format(scStatsFormat,
    [FFps, FFrameMs, FCpuPercentOfOneCore, LOfMachine, FLogicalCpuCount,
     AParticleCount, AOrbCount, ASimTime, FPlatformLabel, FBackendLabel]);
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
  LY: Single;
  i: Integer;
begin
  if ACanvas = nil then
  begin
    Exit;
  end;

  LBar := TRectF.Create(ADest.Left, ADest.Bottom - cStatsHudHeight, ADest.Right, ADest.Bottom);

  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.Color := cStatsBarColor;
  ACanvas.DrawRect(LBar, LPaint);

  // TStringList.Text handles CRLF; do not use SplitString with sLineBreak.
  LLines := TStringList.Create;
  try
    LLines.Text := AText;
    LFont := TSkFont.Create(TSkTypeface.MakeDefault, cStatsFontSize);
    LPaint.Color := cStatsTextColor;

    for i := 0 to Min(1, LLines.Count - 1) do
    begin
      if i = 0 then
        LY := LBar.Top + cStatsLine1Y
      else
        LY := LBar.Top + cStatsLine2Y;

      if LLines[i] <> '' then
      begin
        LPaint.Color := cStatsTextColor;
        ACanvas.DrawSimpleText(
          LLines[i],
          LBar.Left + cStatsTextPadX,
          LY,
          LFont,
          LPaint);
      end;
    end;
  finally
    LLines.Free;
  end;
end;

end.