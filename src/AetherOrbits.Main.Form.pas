/// <summary>
/// AetherOrbits.Main.Form
/// Thin FMX shell for the Aether Orbits demo.
/// </summary>
///
/// <remarks>
/// Owns UI (form + Skia paint box + stats footer) and wires the standalone
/// TGameLoop to TAetherScene. TGameLoop knows nothing about this form or the
/// scene; its core is the ProcessAnimation override (FMX Display Link / Delphi 13).
/// Simulation lives in AetherOrbits.Scene; drawing in AetherOrbits.Scene.Renderer.
/// The game loop is started in FormShow so the form is visible and Root is valid.
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
  FMX.Layouts,
  FMX.Objects,
  // Skia
  System.Skia,
  FMX.Skia,
  // Own
  AetherOrbits.GameLoop,
  AetherOrbits.Scene,
  AetherOrbits.Scene.Renderer;

type
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
    FFpsStopwatch: TStopwatch;
    FFrameCount: Integer;
    FFpsWindowStart: Double;
    FLastRenderTime: Double;
    FFps: Integer;
    FFrameMs: Double;
    FStatsRefreshTimer: Double;

    procedure CreateUi;
    procedure DoGameUpdate(const ADeltaTime: Double);
    procedure DoGameRender;
    procedure DoPaintBoxDraw(
      ASender: TObject;
      const ACanvas: ISkCanvas;
      const ADest: TRectF;
      const AOpacity: Single);
    procedure UpdateStatsFooter(const AForce: Boolean = False);
  end;

var
  FormMain: TFormMain;

implementation

{$R *.fmx}

const
  cStatsPanelHeight = 28;
  cStatsRefreshInterval = 0.25; // seconds — avoid UI thrash every frame
  scStatsFormat =
    'FPS: %d  |  Frame: %.1f ms  |  Particles: %d  |  Orbs: %d  |  Sim: %.1f s';

{ TFormMain }

procedure TFormMain.CreateUi;
begin
  // Footer first so Align.Bottom claims space; paint box fills the rest
  // Explicit dark bar (TPanel style is often light grey — white text would vanish)
  FPanelStats := TRectangle.Create(Self);
  FPanelStats.Parent := Self;
  FPanelStats.Align := TAlignLayout.Bottom;
  FPanelStats.Height := cStatsPanelHeight;
  FPanelStats.HitTest := False;
  FPanelStats.Stroke.Kind := TBrushKind.None;
  FPanelStats.Fill.Kind := TBrushKind.Solid;
  FPanelStats.Fill.Color := $FF0B1220; // matches scene night background
  FPanelStats.XRadius := 0;
  FPanelStats.YRadius := 0;

  FLabelStats := TLabel.Create(Self);
  FLabelStats.Parent := FPanelStats;
  FLabelStats.Align := TAlignLayout.Client;
  FLabelStats.HitTest := False;
  FLabelStats.Margins.Left := 12;
  FLabelStats.Margins.Right := 12;
  FLabelStats.VertTextAlign := TTextAlign.Center;
  FLabelStats.StyledSettings := []; // take full control of font/color
  FLabelStats.TextSettings.Font.Size := 12;
  FLabelStats.TextSettings.Font.Style := [TFontStyle.fsBold];
  FLabelStats.TextSettings.FontColor := $FFE8EEF8; // near-white on dark bar
  FLabelStats.TextSettings.HorzAlign := TTextAlign.Leading;
  FLabelStats.Text := 'FPS: —';

  FPaintBox := TSkPaintBox.Create(Self);
  FPaintBox.Parent := Self;
  FPaintBox.Align := TAlignLayout.Client;
  FPaintBox.HitTest := False;
  FPaintBox.OnDraw := DoPaintBoxDraw;
end;

procedure TFormMain.FormCreate(ASender: TObject);
begin
  FScene := TAetherScene.Create;
  CreateUi;

  FFpsStopwatch := TStopwatch.StartNew;
  FFpsWindowStart := 0;
  FLastRenderTime := 0;
  FFrameCount := 0;
  FFps := 0;
  FFrameMs := 0;
  FStatsRefreshTimer := 0;

  FScene.Initialize(ClientWidth, ClientHeight - cStatsPanelHeight);

  // Parent is set to the form inside TGameLoop.Create (Display Link needs Root)
  FGameLoop := TGameLoop.Create(Self);
  FGameLoop.OnUpdate := DoGameUpdate;
  FGameLoop.OnRender := DoGameRender;
  // StartLoop in FormShow — form must be visible for TAnimation.Start
end;

procedure TFormMain.FormShow(ASender: TObject);
begin
  if Assigned(FGameLoop) and not FGameLoop.Running then
  begin
    FGameLoop.StartLoop;
  end;
  UpdateStatsFooter(True);
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
  if Assigned(FScene) then
  begin
    FScene.SetViewport(ClientWidth, Max(1, ClientHeight - cStatsPanelHeight));
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
  FScene.SetViewport(ClientWidth, Max(1, ClientHeight - cStatsPanelHeight));
  FScene.Update(ADeltaTime);

  FStatsRefreshTimer := FStatsRefreshTimer + ADeltaTime;
  if FStatsRefreshTimer >= cStatsRefreshInterval then
  begin
    FStatsRefreshTimer := 0;
    UpdateStatsFooter(False);
  end;
end;

procedure TFormMain.DoGameRender;
var
  LNow: Double;
begin
  LNow := FFpsStopwatch.Elapsed.TotalSeconds;
  if FLastRenderTime > 0 then
  begin
    FFrameMs := (LNow - FLastRenderTime) * 1000.0;
  end;
  FLastRenderTime := LNow;

  Inc(FFrameCount);
  if (LNow - FFpsWindowStart) >= 1.0 then
  begin
    FFps := FFrameCount;
    FFrameCount := 0;
    FFpsWindowStart := LNow;
  end;

  FPaintBox.Redraw;
end;

procedure TFormMain.UpdateStatsFooter(const AForce: Boolean);
begin
  if not Assigned(FLabelStats) or not Assigned(FScene) then
  begin
    Exit;
  end;

  FLabelStats.Text := Format(
    scStatsFormat,
    [FFps, FFrameMs, FScene.ParticleCount, FScene.OrbCount, FScene.Time]);
end;

procedure TFormMain.DoPaintBoxDraw(
  ASender: TObject;
  const ACanvas: ISkCanvas;
  const ADest: TRectF;
  const AOpacity: Single);
begin
  // AOpacity reserved by TSkDrawEvent; scene draws fully opaque
  TAetherSceneRenderer.Draw(FScene, ACanvas, ADest);
end;

end.
