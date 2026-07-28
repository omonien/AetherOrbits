/// <summary>
/// AetherOrbits.Main.Form
/// Thin FMX shell for the Aether Orbits demo.
/// </summary>
///
/// <remarks>
/// Owns UI (form + Skia paint box) and wires the standalone TGameLoop to
/// TAetherScene. The stats footer is drawn as a Skia overlay inside the paint
/// box so it stays visible under Metal (FMX TLabel/TRectangle can be covered
/// or fail to composite when GlobalUseSkia + Metal is active).
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit AetherOrbits.Main.Form;

interface

uses
  // System
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Diagnostics,
  System.Math,
  System.StrUtils,
  // FMX
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  // Skia
  System.Skia,
  FMX.Skia,
  // Own
  AetherOrbits.GameLoop,
  AetherOrbits.Scene,
  AetherOrbits.Scene.Renderer,
  AetherOrbits.RuntimeInfo;

type
  /// <summary>
  /// Rolling FPS / frame-time samples for the stats footer.
  /// </summary>
  TFrameStats = record
    Stopwatch: TStopwatch;
    FrameCount: Integer;
    WindowStart: Double;
    LastRenderTime: Double;
    Fps: Integer;
    FrameMs: Double;
    RefreshTimer: Double;
    PlatformLabel: string;
    BackendLabel: string;
    procedure Reset;
    procedure CaptureEnvironment;
    procedure OnFrameRendered;
    function ShouldRefreshFooter(const ADeltaTime, AInterval: Double): Boolean;
    function FormatLine(
      const AParticleCount, AOrbCount: Integer;
      const ASimTime: Double): string;
  end;

  /// <summary>
  /// Main demo window: game loop + scene + Skia paint box (with HUD stats).
  /// </summary>
  TFormMain = class(TForm)
    procedure FormCreate(ASender: TObject);
    procedure FormDestroy(ASender: TObject);
    procedure FormShow(ASender: TObject);
    procedure FormMouseMove(ASender: TObject; AShift: TShiftState; AX, AY: Single);
    procedure FormResize(ASender: TObject);
  private
    FPaintBox: TSkPaintBox;
    FGameLoop: TGameLoop;
    FScene: TAetherScene;
    FFrameStats: TFrameStats;
    FStatsText: string;

    procedure CreateUi;
    function GetSceneViewportHeight: Single;
    procedure SyncViewportFromPaintBox;
    procedure EnsureSceneInitialized;
    procedure DoGameUpdate(const ADeltaTime: Double);
    procedure DoGameRender;
    procedure DoPaintBoxDraw(
      ASender: TObject;
      const ACanvas: ISkCanvas;
      const ADest: TRectF;
      const AOpacity: Single);
    procedure DrawStatsOverlay(const ACanvas: ISkCanvas; const ADest: TRectF);
    procedure UpdateStatsFooter;
  end;

var
  FormMain: TFormMain;

implementation

{$R *.fmx}

const
  cStatsPanelHeight = 44;
  cStatsRefreshInterval = 0.25;
  cStatsBarColor = $FF0B1220;
  cStatsTextColor = $FFE8EEF8;
  cStatsFontSize = 12;
  cStatsTextPadX = 12;
  cStatsLine1Y = 16;
  cStatsLine2Y = 34;
  scStatsFormat =
    'FPS: %d  |  Frame: %.1f ms  |  Particles: %d  |  Orbs: %d  |  Sim time: %.1f s' + sLineBreak +
    'Platform: %s  |  Backend: %s';

{ TFrameStats }

procedure TFrameStats.Reset;
begin
  Stopwatch := TStopwatch.StartNew;
  FrameCount := 0;
  WindowStart := 0;
  LastRenderTime := 0;
  Fps := 0;
  FrameMs := 0;
  RefreshTimer := 0;
  PlatformLabel := '';
  BackendLabel := '';
end;

procedure TFrameStats.CaptureEnvironment;
begin
  PlatformLabel := GetHostPlatformLabel;
  BackendLabel := GetActiveRenderBackendLabel;
end;

procedure TFrameStats.OnFrameRendered;
var
  LNow: Double;
begin
  LNow := Stopwatch.Elapsed.TotalSeconds;
  if LastRenderTime > 0 then
  begin
    FrameMs := (LNow - LastRenderTime) * 1000.0;
  end;
  LastRenderTime := LNow;

  Inc(FrameCount);
  if (LNow - WindowStart) >= 1.0 then
  begin
    Fps := FrameCount;
    FrameCount := 0;
    WindowStart := LNow;
  end;
end;

function TFrameStats.ShouldRefreshFooter(const ADeltaTime, AInterval: Double): Boolean;
begin
  RefreshTimer := RefreshTimer + ADeltaTime;
  Result := RefreshTimer >= AInterval;
  if Result then
  begin
    RefreshTimer := 0;
  end;
end;

function TFrameStats.FormatLine(
  const AParticleCount, AOrbCount: Integer;
  const ASimTime: Double): string;
begin
  Result := Format(scStatsFormat,
    [Fps, FrameMs, AParticleCount, AOrbCount, ASimTime, PlatformLabel, BackendLabel]);
end;

{ TFormMain }

procedure TFormMain.CreateUi;
begin
  // Full-client Skia surface; stats are drawn as an overlay (Metal-safe)
  FPaintBox := TSkPaintBox.Create(Self);
  FPaintBox.Parent := Self;
  FPaintBox.Align := TAlignLayout.Client;
  FPaintBox.HitTest := False;
  FPaintBox.OnDraw := DoPaintBoxDraw;
  FStatsText := 'FPS: -';
end;

function TFormMain.GetSceneViewportHeight: Single;
begin
  Result := Max(1, FPaintBox.Height - cStatsPanelHeight);
end;

procedure TFormMain.SyncViewportFromPaintBox;
begin
  if not Assigned(FScene) or not Assigned(FPaintBox) then
  begin
    Exit;
  end;

  FScene.SetViewport(Max(1, FPaintBox.Width), GetSceneViewportHeight);
end;

procedure TFormMain.EnsureSceneInitialized;
begin
  if FScene.Initialized then
  begin
    SyncViewportFromPaintBox;
  end
  else
  begin
    FScene.Initialize(Max(1, FPaintBox.Width), GetSceneViewportHeight);
  end;
end;

procedure TFormMain.FormCreate(ASender: TObject);
begin
  FScene := TAetherScene.Create;
  CreateUi;
  FFrameStats.Reset;

  FGameLoop := TGameLoop.Create(Self);
  FGameLoop.OnUpdate := DoGameUpdate;
  FGameLoop.OnRender := DoGameRender;
end;

procedure TFormMain.FormShow(ASender: TObject);
begin
  EnsureSceneInitialized;

  if Assigned(FGameLoop) and not FGameLoop.Running then
  begin
    FGameLoop.StartLoop;
  end;

  FFrameStats.CaptureEnvironment;
  UpdateStatsFooter;
end;

procedure TFormMain.FormDestroy(ASender: TObject);
begin
  if Assigned(FGameLoop) then
  begin
    FGameLoop.StopLoop;
  end;
  FreeAndNil(FScene);
end;

procedure TFormMain.FormResize(ASender: TObject);
begin
  if Assigned(FScene) and FScene.Initialized then
  begin
    SyncViewportFromPaintBox;
  end;
end;

procedure TFormMain.FormMouseMove(ASender: TObject; AShift: TShiftState; AX, AY: Single);
begin
  if Assigned(FScene) then
  begin
    FScene.SetMousePosition(TPointF.Create(AX, AY));
  end;
end;

procedure TFormMain.DoGameUpdate(const ADeltaTime: Double);
begin
  FScene.Update(ADeltaTime);

  if FFrameStats.ShouldRefreshFooter(ADeltaTime, cStatsRefreshInterval) then
  begin
    UpdateStatsFooter;
  end;
end;

procedure TFormMain.DoGameRender;
begin
  FFrameStats.OnFrameRendered;
  FPaintBox.Redraw;
end;

procedure TFormMain.UpdateStatsFooter;
begin
  if not Assigned(FScene) then
  begin
    Exit;
  end;

  FStatsText := FFrameStats.FormatLine(
    FScene.ParticleCount,
    FScene.OrbCount,
    FScene.Time);
end;

procedure TFormMain.DrawStatsOverlay(const ACanvas: ISkCanvas; const ADest: TRectF);
var
  LBar: TRectF;
  LPaint: ISkPaint;
  LFont: ISkFont;
  LLines: TStringList;
  LY: Single;
  i: Integer;
begin
  LBar := TRectF.Create(ADest.Left, ADest.Bottom - cStatsPanelHeight, ADest.Right, ADest.Bottom);

  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.Color := cStatsBarColor;
  ACanvas.DrawRect(LBar, LPaint);

  // Do not use SplitString(..., sLineBreak): it treats the delimiter as a set of
  // characters, so CRLF yields an empty middle line and drops the backend row.
  LLines := TStringList.Create;
  try
    LLines.Text := FStatsText;
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
        // Re-assert fill color each line (some Skia backends keep paint state)
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

procedure TFormMain.DoPaintBoxDraw(
  ASender: TObject;
  const ACanvas: ISkCanvas;
  const ADest: TRectF;
  const AOpacity: Single);
var
  LSceneDest: TRectF;
begin
  // Scene in the upper region; stats HUD in the bottom strip (same Metal surface)
  LSceneDest := ADest;
  LSceneDest.Bottom := Max(ADest.Top + 1, ADest.Bottom - cStatsPanelHeight);
  TAetherSceneRenderer.Draw(FScene, ACanvas, LSceneDest);
  DrawStatsOverlay(ACanvas, ADest);
end;

end.