/// <summary>
/// AetherOrbits.Main.Form
/// Thin FMX shell for the Aether Orbits demo.
/// </summary>
///
/// <remarks>
/// Owns UI (form + Skia paint box + stats footer) and wires the standalone
/// TGameLoop to TAetherScene. Viewport size is taken only from the paint box
/// (layout), never invented with footer-height arithmetic on the form.
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
  // FMX
  FMX.Types,
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Forms,
  FMX.Graphics,
  FMX.StdCtrls,
  FMX.Objects,
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
  /// Main demo window: game loop + scene + paint box + stats footer.
  /// </summary>
  TFormMain = class(TForm)
    procedure FormCreate(ASender: TObject);
    procedure FormDestroy(ASender: TObject);
    procedure FormShow(ASender: TObject);
    procedure FormMouseMove(ASender: TObject; AShift: TShiftState; AX, AY: Single);
    procedure FormResize(ASender: TObject);
  private
    FPaintBox: TSkPaintBox;
    FPanelStats: TRectangle;
    FLabelStats: TLabel;
    FGameLoop: TGameLoop;
    FScene: TAetherScene;
    FFrameStats: TFrameStats;

    procedure CreateUi;
    procedure SyncViewportFromPaintBox;
    procedure EnsureSceneInitialized;
    procedure DoGameUpdate(const ADeltaTime: Double);
    procedure DoGameRender;
    procedure DoPaintBoxDraw(
      ASender: TObject;
      const ACanvas: ISkCanvas;
      const ADest: TRectF;
      const AOpacity: Single);
    procedure UpdateStatsFooter;
  end;

var
  FormMain: TFormMain;

implementation

{$R *.fmx}

const
  cStatsPanelHeight = 40;
  cStatsRefreshInterval = 0.25;
  cStatsBarColor = $FF0B1220;
  cStatsTextColor = $FFE8EEF8;
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
  FPanelStats := TRectangle.Create(Self);
  FPanelStats.Parent := Self;
  FPanelStats.Align := TAlignLayout.Bottom;
  FPanelStats.Height := cStatsPanelHeight;
  FPanelStats.HitTest := False;
  FPanelStats.Stroke.Kind := TBrushKind.None;
  FPanelStats.Fill.Kind := TBrushKind.Solid;
  FPanelStats.Fill.Color := cStatsBarColor;

  FLabelStats := TLabel.Create(Self);
  FLabelStats.Parent := FPanelStats;
  FLabelStats.Align := TAlignLayout.Client;
  FLabelStats.HitTest := False;
  FLabelStats.Margins.Left := 12;
  FLabelStats.Margins.Right := 12;
  FLabelStats.VertTextAlign := TTextAlign.Center;
  FLabelStats.StyledSettings := [];
  FLabelStats.TextSettings.Font.Size := 12;
  FLabelStats.TextSettings.Font.Style := [TFontStyle.fsBold];
  FLabelStats.TextSettings.FontColor := cStatsTextColor;
  FLabelStats.TextSettings.HorzAlign := TTextAlign.Leading;
  FLabelStats.WordWrap := True;
  FLabelStats.Text := 'FPS: -';

  FPaintBox := TSkPaintBox.Create(Self);
  FPaintBox.Parent := Self;
  FPaintBox.Align := TAlignLayout.Client;
  FPaintBox.HitTest := False;
  FPaintBox.OnDraw := DoPaintBoxDraw;
end;

procedure TFormMain.SyncViewportFromPaintBox;
begin
  if not Assigned(FScene) or not Assigned(FPaintBox) then
  begin
    Exit;
  end;

  FScene.SetViewport(Max(1, FPaintBox.Width), Max(1, FPaintBox.Height));
end;

procedure TFormMain.EnsureSceneInitialized;
begin
  if FScene.Initialized then
  begin
    SyncViewportFromPaintBox;
  end
  else
  begin
    FScene.Initialize(Max(1, FPaintBox.Width), Max(1, FPaintBox.Height));
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
  // Initialize + StartLoop in FormShow (layout size + visibility)
end;

procedure TFormMain.FormShow(ASender: TObject);
begin
  EnsureSceneInitialized;

  if Assigned(FGameLoop) and not FGameLoop.Running then
  begin
    FGameLoop.StartLoop;
  end;

  // Backend is registered after GlobalUseSkia + app init
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
  // Viewport is layout-owned — never re-derived from form height here
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
  if not Assigned(FLabelStats) or not Assigned(FScene) then
  begin
    Exit;
  end;

  FLabelStats.Text := FFrameStats.FormatLine(
    FScene.ParticleCount,
    FScene.OrbCount,
    FScene.Time);
end;

procedure TFormMain.DoPaintBoxDraw(
  ASender: TObject;
  const ACanvas: ISkCanvas;
  const ADest: TRectF;
  const AOpacity: Single);
begin
  TAetherSceneRenderer.Draw(FScene, ACanvas, ADest);
end;

end.
