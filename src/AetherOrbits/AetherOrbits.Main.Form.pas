/// <summary>
/// AetherOrbits.Main.Form
/// Thin FMX shell for the Aether Orbits demo.
/// </summary>
///
/// <remarks>
/// Form handling only: wires controls, TGameLoop, TAetherScene, and TSkPaintBox.
/// Shared surface/chrome helpers live in FMXAnimation.DemoShell; simulation and
/// drawing stay in Scene / Scene.Renderer.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit AetherOrbits.Main.Form;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Math,
  FMX.Types,
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.StdCtrls,
  FMX.Layouts,
  FMX.Objects,
  FMX.Forms,
  FMX.Graphics,
  System.Skia,
  FMX.Skia,
  FMXAnimation.GameLoop,
  FMXAnimation.DemoShell,
  FMXAnimation.Stats.Hud,
  FMXAnimation.SystemInfo,
  AetherOrbits.Scene,
  AetherOrbits.Scene.Renderer;

type
  /// <summary>
  /// Main demo window: UI shell for game loop + scene + Skia surface.
  /// </summary>
  TFormMain = class(TForm)
    LayoutPreferred: TLayout;
    RectPreferredBg: TRectangle;
    RectPreferredBottomLine: TRectangle;
    LayoutPreferredInner: TLayout;
    LabelPreferred: TLabel;
    LayoutPreferredSeg: TLayout;
    RectSeg30: TRectangle;
    LabelSeg30: TLabel;
    RectSeg60: TRectangle;
    LabelSeg60: TLabel;
    RectSeg120: TRectangle;
    LabelSeg120: TLabel;
    LabelPreferredHint: TLabel;
    LayoutScene: TLayout;
    procedure FormCreate(ASender: TObject);
    procedure FormDestroy(ASender: TObject);
    procedure FormShow(ASender: TObject);
    procedure FormResize(ASender: TObject);
    procedure PreferredSegClick(ASender: TObject);
  private
    FPaintBox: TSkPaintBox;
    FGameLoop: TGameLoop;
    FScene: TAetherScene;
    FStatsHud: TStatsHudModel;
    FApplyingPreferred: Boolean;

    procedure CreateUi;
    procedure SyncPreferredSegmentsFromGlobal;
    procedure SyncViewportFromPaintBox;
    procedure EnsureSceneInitialized;
    procedure DoGameUpdate(const ADeltaTime: Double);
    procedure DoGameRender;
    procedure DoPaintBoxDraw(
      ASender: TObject;
      const ACanvas: ISkCanvas;
      const ADest: TRectF;
      const AOpacity: Single);
    procedure DoPaintBoxMouseMove(ASender: TObject; AShift: TShiftState; AX, AY: Single);
    procedure DoPaintBoxMouseDown(ASender: TObject; AButton: TMouseButton;
      AShift: TShiftState; AX, AY: Single);
    procedure UpdateStatsFooter;
    procedure ApplyPreferredFpsFromUi(const AFps: Integer);
  end;

var
  FormMain: TFormMain;

implementation

{$R *.fmx}

{ TFormMain }

procedure TFormMain.SyncPreferredSegmentsFromGlobal;
var
  LFps: Integer;
begin
  LFps := GetPreferredFramesPerSecond;
  if not ((LFps = 30) or (LFps = 60) or (LFps = 120)) then
  begin
    LFps := 60;
  end;

  FApplyingPreferred := True;
  try
    StyleSegmentChip(RectSeg30, LabelSeg30, LFps = 30);
    StyleSegmentChip(RectSeg60, LabelSeg60, LFps = 60);
    StyleSegmentChip(RectSeg120, LabelSeg120, LFps = 120);
  finally
    FApplyingPreferred := False;
  end;
end;

procedure TFormMain.CreateUi;
begin
  // Paint box only under LayoutScene — never form Align=Client (covers toolbar).
  FPaintBox := CreateClientPaintBox(Self, LayoutScene);
  FPaintBox.OnDraw := DoPaintBoxDraw;
  FPaintBox.OnMouseMove := DoPaintBoxMouseMove;
  FPaintBox.OnMouseDown := DoPaintBoxMouseDown;

  RectPreferredBg.Fill.Color := cDemoBarBg;
  RectPreferredBottomLine.Fill.Color := cDemoBarLine;
  StyleDemoLabel(LabelPreferred, cDemoLabelMuted);
  StyleDemoLabel(LabelPreferredHint, cDemoHintMuted);
  StyleDemoLabel(LabelSeg30, cDemoSegIdleText);
  StyleDemoLabel(LabelSeg60, cDemoSegIdleText);
  StyleDemoLabel(LabelSeg120, cDemoSegIdleText);

  RectSeg60.Margins.Left := 8;
  RectSeg120.Margins.Left := 8;

  LayoutPreferred.Visible := True;
  LayoutPreferred.BringToFront;
  LabelPreferredHint.Visible := ClientWidth >= 640;
  SyncPreferredSegmentsFromGlobal;
end;

procedure TFormMain.SyncViewportFromPaintBox;
begin
  if not Assigned(FScene) or not Assigned(FPaintBox) then
  begin
    Exit;
  end;
  FScene.SetViewport(
    Max(1, FPaintBox.Width),
    GetSceneViewportHeight(FPaintBox.Width, FPaintBox.Height));
end;

procedure TFormMain.EnsureSceneInitialized;
begin
  if FScene.Initialized then
  begin
    SyncViewportFromPaintBox;
  end
  else
  begin
    FScene.Initialize(
      Max(1, FPaintBox.Width),
      GetSceneViewportHeight(FPaintBox.Width, FPaintBox.Height));
  end;
end;

procedure TFormMain.ApplyPreferredFpsFromUi(const AFps: Integer);
begin
  ApplyPreferredFps(AFps, FGameLoop, True, Visible);
  SyncPreferredSegmentsFromGlobal;
  UpdateStatsFooter;
end;

procedure TFormMain.PreferredSegClick(ASender: TObject);
var
  LFps: Integer;
begin
  if FApplyingPreferred then
  begin
    Exit;
  end;

  if (ASender = RectSeg30) or (ASender = LabelSeg30) then
    LFps := 30
  else if (ASender = RectSeg120) or (ASender = LabelSeg120) then
    LFps := 120
  else
    LFps := 60;

  ApplyPreferredFpsFromUi(LFps);
end;

procedure TFormMain.FormCreate(ASender: TObject);
begin
  FScene := TAetherScene.Create;
  CreateUi;
  FStatsHud.Reset;

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

  FStatsHud.CaptureEnvironment;
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
  if Assigned(LabelPreferredHint) then
  begin
    LabelPreferredHint.Visible := ClientWidth >= 640;
  end;
  if Assigned(FScene) and FScene.Initialized then
  begin
    SyncViewportFromPaintBox;
  end;
end;

procedure TFormMain.DoPaintBoxMouseMove(
  ASender: TObject;
  AShift: TShiftState;
  AX, AY: Single);
begin
  if Assigned(FScene) then
  begin
    FScene.SetMousePosition(TPointF.Create(AX, AY));
  end;
end;

procedure TFormMain.DoPaintBoxMouseDown(
  ASender: TObject;
  AButton: TMouseButton;
  AShift: TShiftState;
  AX, AY: Single);
begin
  if Assigned(FScene) and (AButton = TMouseButton.mbLeft) then
  begin
    FScene.PointerDown(TPointF.Create(AX, AY));
  end;
end;

procedure TFormMain.DoGameUpdate(const ADeltaTime: Double);
var
  LLocal: TPointF;
begin
  // Poll pointer while hovering — some FMX/Skia paths starve OnMouseMove.
  if Assigned(FPaintBox) and FPaintBox.IsMouseOver then
  begin
    LLocal := FPaintBox.ScreenToLocal(Screen.MousePos);
    if FPaintBox.LocalRect.Contains(LLocal) then
    begin
      FScene.SetMousePosition(LLocal);
    end;
  end;

  FScene.Update(ADeltaTime);

  if FStatsHud.ShouldRefresh(ADeltaTime) then
  begin
    UpdateStatsFooter;
  end;
end;

procedure TFormMain.DoGameRender;
begin
  FStatsHud.OnFrameRendered;
  FPaintBox.Redraw;
end;

procedure TFormMain.UpdateStatsFooter;
begin
  if not Assigned(FScene) then
  begin
    Exit;
  end;

  FStatsHud.RefreshText(
    FScene.ParticleCount,
    FScene.OrbCount,
    FScene.Time,
    FPaintBox.Width);
end;

procedure TFormMain.DoPaintBoxDraw(
  ASender: TObject;
  const ACanvas: ISkCanvas;
  const ADest: TRectF;
  const AOpacity: Single);
begin
  TAetherSceneRenderer.Draw(FScene, ACanvas, GetSceneDestInPaintBox(ADest));
  TStatsHudPainter.Draw(ACanvas, ADest, FStatsHud.Text);
end;

end.
