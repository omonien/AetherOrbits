/// <summary>
/// Helios.Main.Form
/// Thin FMX shell for the Helios solar-system demo.
/// </summary>
///
/// <remarks>
/// Wires TGameLoop to THeliosScene and a TSkPaintBox. Reuses AetherOrbits
/// GameLoop, SystemInfo, and Stats.Hud. Dark chrome matches Aether Orbits.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit Helios.Main.Form;

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
  AetherOrbits.GameLoop,
  AetherOrbits.Stats.Hud,
  AetherOrbits.SystemInfo,
  Helios.Scene,
  Helios.Scene.Renderer;

type
  /// <summary>
  /// Helios main window: game loop + solar system scene + Skia paint box.
  /// </summary>
  TFormHeliosMain = class(TForm)
    LayoutToolbar: TLayout;
    RectToolbarBg: TRectangle;
    RectToolbarBottomLine: TRectangle;
    LayoutToolbarInner: TLayout;
    LabelSpeed: TLabel;
    LayoutSpeedSeg: TLayout;
    RectSpeed025: TRectangle;
    LabelSpeed025: TLabel;
    RectSpeed1: TRectangle;
    LabelSpeed1: TLabel;
    RectSpeed5: TRectangle;
    LabelSpeed5: TLabel;
    RectSpeed20: TRectangle;
    LabelSpeed20: TLabel;
    RectPause: TRectangle;
    LabelPause: TLabel;
    RectTrails: TRectangle;
    LabelTrails: TLabel;
    RectOverview: TRectangle;
    LabelOverview: TLabel;
    LabelPreferred: TLabel;
    LayoutPreferredSeg: TLayout;
    RectSeg30: TRectangle;
    LabelSeg30: TLabel;
    RectSeg60: TRectangle;
    LabelSeg60: TLabel;
    RectSeg120: TRectangle;
    LabelSeg120: TLabel;
    LabelHint: TLabel;
    LayoutScene: TLayout;
    procedure FormCreate(ASender: TObject);
    procedure FormDestroy(ASender: TObject);
    procedure FormShow(ASender: TObject);
    procedure FormResize(ASender: TObject);
    procedure PreferredSegClick(ASender: TObject);
    procedure SpeedSegClick(ASender: TObject);
    procedure PauseClick(ASender: TObject);
    procedure TrailsClick(ASender: TObject);
    procedure OverviewClick(ASender: TObject);
  private
    FPaintBox: TSkPaintBox;
    FGameLoop: TGameLoop;
    FScene: THeliosScene;
    FStatsHud: TStatsHudModel;
    FApplyingPreferred: Boolean;

    procedure CreateUi;
    procedure StyleSegment(const ARect: TRectangle; const ALabel: TLabel;
      const ASelected: Boolean);
    procedure SyncPreferredSegmentsFromGlobal;
    procedure SyncSpeedSegments;
    procedure SyncToggleButtons;
    function GetSceneViewportHeight: Single;
    function GetSceneDrawRect: TRectF;
    procedure SyncViewportFromPaintBox;
    procedure EnsureSceneInitialized;
    procedure DoGameUpdate(const ADeltaTime: Double);
    procedure DoGameRender;
    procedure DoPaintBoxDraw(
      ASender: TObject;
      const ACanvas: ISkCanvas;
      const ADest: TRectF;
      const AOpacity: Single);
    procedure DoPaintBoxMouseDown(ASender: TObject; AButton: TMouseButton;
      AShift: TShiftState; AX, AY: Single);
    procedure UpdateStatsFooter;
    procedure ApplyPreferredFps(const AFps: Integer; const ARestartLoop: Boolean);
  end;

var
  FormHeliosMain: TFormHeliosMain;

implementation

{$R *.fmx}

const
  cBarBg = $FF0B1220;
  cBarLine = $FF1E2A3C;
  cSegIdleFill = $FF151C2A;
  cSegIdleStroke = $FF2A3A50;
  cSegIdleText = $FF9AABC4;
  cSegSelFill = $FF2563A8;
  cSegSelStroke = $FF3B82C4;
  cSegSelText = $FFE8EEF8;
  cLabelMuted = $FF8B9BB4;
  cHintMuted = $FF5C6B82;

{ TFormHeliosMain }

procedure TFormHeliosMain.StyleSegment(
  const ARect: TRectangle;
  const ALabel: TLabel;
  const ASelected: Boolean);
begin
  if ASelected then
  begin
    ARect.Fill.Color := cSegSelFill;
    ARect.Stroke.Color := cSegSelStroke;
    ALabel.TextSettings.FontColor := cSegSelText;
  end
  else
  begin
    ARect.Fill.Color := cSegIdleFill;
    ARect.Stroke.Color := cSegIdleStroke;
    ALabel.TextSettings.FontColor := cSegIdleText;
  end;
end;

procedure TFormHeliosMain.SyncPreferredSegmentsFromGlobal;
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
    StyleSegment(RectSeg30, LabelSeg30, LFps = 30);
    StyleSegment(RectSeg60, LabelSeg60, LFps = 60);
    StyleSegment(RectSeg120, LabelSeg120, LFps = 120);
  finally
    FApplyingPreferred := False;
  end;
end;

procedure TFormHeliosMain.SyncSpeedSegments;
var
  LSpeed: Single;
begin
  if not Assigned(FScene) then
  begin
    Exit;
  end;
  LSpeed := FScene.SimSpeed;
  StyleSegment(RectSpeed025, LabelSpeed025, Abs(LSpeed - 0.25) < 0.01);
  StyleSegment(RectSpeed1, LabelSpeed1, Abs(LSpeed - 1.0) < 0.01);
  StyleSegment(RectSpeed5, LabelSpeed5, Abs(LSpeed - 5.0) < 0.01);
  StyleSegment(RectSpeed20, LabelSpeed20, Abs(LSpeed - 20.0) < 0.01);
end;

procedure TFormHeliosMain.SyncToggleButtons;
begin
  if not Assigned(FScene) then
  begin
    Exit;
  end;
  StyleSegment(RectPause, LabelPause, FScene.Paused);
  if FScene.Paused then
  begin
    LabelPause.Text := 'Resume';
  end
  else
  begin
    LabelPause.Text := 'Pause';
  end;
  StyleSegment(RectTrails, LabelTrails, FScene.ShowTrails);
end;

procedure TFormHeliosMain.CreateUi;
begin
  FPaintBox := TSkPaintBox.Create(Self);
  FPaintBox.Parent := LayoutScene;
  FPaintBox.Align := TAlignLayout.Client;
  FPaintBox.HitTest := True;
  FPaintBox.CanFocus := False;
  FPaintBox.OnDraw := DoPaintBoxDraw;
  FPaintBox.OnMouseDown := DoPaintBoxMouseDown;
  LayoutScene.HitTest := False;

  RectToolbarBg.Fill.Color := cBarBg;
  RectToolbarBottomLine.Fill.Color := cBarLine;

  LabelSpeed.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  LabelSpeed.TextSettings.FontColor := cLabelMuted;
  LabelPreferred.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  LabelPreferred.TextSettings.FontColor := cLabelMuted;
  LabelHint.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  LabelHint.TextSettings.FontColor := cHintMuted;

  LabelSpeed025.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  LabelSpeed1.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  LabelSpeed5.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  LabelSpeed20.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  LabelPause.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  LabelTrails.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  LabelOverview.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  LabelSeg30.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  LabelSeg60.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  LabelSeg120.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];

  // Gaps between chip groups so the bar does not pack flush.
  RectSpeed1.Margins.Left := 6;
  RectSpeed5.Margins.Left := 6;
  RectSpeed20.Margins.Left := 6;
  RectPause.Margins.Left := 12;
  RectTrails.Margins.Left := 6;
  RectOverview.Margins.Left := 6;
  LabelPreferred.Margins.Left := 16;
  RectSeg60.Margins.Left := 6;
  RectSeg120.Margins.Left := 6;

  LayoutToolbar.Visible := True;
  LayoutToolbar.BringToFront;
  LabelHint.Visible := ClientWidth >= 1100;
  SyncPreferredSegmentsFromGlobal;
  SyncSpeedSegments;
  SyncToggleButtons;
end;

function TFormHeliosMain.GetSceneViewportHeight: Single;
begin
  Result := Max(1, FPaintBox.Height - GetStatsHudHeight(FPaintBox.Width));
end;

function TFormHeliosMain.GetSceneDrawRect: TRectF;
begin
  Result := TRectF.Create(0, 0, Max(1, FPaintBox.Width), GetSceneViewportHeight);
end;

procedure TFormHeliosMain.SyncViewportFromPaintBox;
begin
  if not Assigned(FScene) or not Assigned(FPaintBox) then
  begin
    Exit;
  end;
  FScene.SetViewport(Max(1, FPaintBox.Width), GetSceneViewportHeight);
end;

procedure TFormHeliosMain.EnsureSceneInitialized;
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

procedure TFormHeliosMain.ApplyPreferredFps(const AFps: Integer; const ARestartLoop: Boolean);
var
  LWasRunning: Boolean;
begin
  if GetPreferredFramesPerSecond = AFps then
  begin
    SyncPreferredSegmentsFromGlobal;
    Exit;
  end;

  SetPreferredFramesPerSecond(AFps);
  SyncPreferredSegmentsFromGlobal;

  if ARestartLoop and Assigned(FGameLoop) then
  begin
    LWasRunning := FGameLoop.Running;
    FGameLoop.StopLoop;
    if LWasRunning or Visible then
    begin
      FGameLoop.StartLoop;
    end;
  end;

  UpdateStatsFooter;
end;

procedure TFormHeliosMain.PreferredSegClick(ASender: TObject);
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

  ApplyPreferredFps(LFps, True);
end;

procedure TFormHeliosMain.SpeedSegClick(ASender: TObject);
var
  LSpeed: Single;
begin
  if not Assigned(FScene) then
  begin
    Exit;
  end;

  if (ASender = RectSpeed025) or (ASender = LabelSpeed025) then
    LSpeed := 0.25
  else if (ASender = RectSpeed5) or (ASender = LabelSpeed5) then
    LSpeed := 5.0
  else if (ASender = RectSpeed20) or (ASender = LabelSpeed20) then
    LSpeed := 20.0
  else
    LSpeed := 1.0;

  FScene.SetSimSpeed(LSpeed);
  SyncSpeedSegments;
  UpdateStatsFooter;
end;

procedure TFormHeliosMain.PauseClick(ASender: TObject);
begin
  if not Assigned(FScene) then
  begin
    Exit;
  end;
  FScene.TogglePause;
  SyncToggleButtons;
  UpdateStatsFooter;
end;

procedure TFormHeliosMain.TrailsClick(ASender: TObject);
begin
  if not Assigned(FScene) then
  begin
    Exit;
  end;
  FScene.SetShowTrails(not FScene.ShowTrails);
  SyncToggleButtons;
end;

procedure TFormHeliosMain.OverviewClick(ASender: TObject);
begin
  if not Assigned(FScene) then
  begin
    Exit;
  end;
  FScene.FocusOverview;
  UpdateStatsFooter;
end;

procedure TFormHeliosMain.FormCreate(ASender: TObject);
begin
  FScene := THeliosScene.Create;
  CreateUi;
  FStatsHud.Reset;

  FGameLoop := TGameLoop.Create(Self);
  FGameLoop.OnUpdate := DoGameUpdate;
  FGameLoop.OnRender := DoGameRender;
end;

procedure TFormHeliosMain.FormShow(ASender: TObject);
begin
  EnsureSceneInitialized;
  SyncSpeedSegments;
  SyncToggleButtons;

  if Assigned(FGameLoop) and not FGameLoop.Running then
  begin
    FGameLoop.StartLoop;
  end;

  FStatsHud.CaptureEnvironment;
  UpdateStatsFooter;
end;

procedure TFormHeliosMain.FormDestroy(ASender: TObject);
begin
  if Assigned(FGameLoop) then
  begin
    FGameLoop.StopLoop;
  end;
  FreeAndNil(FScene);
end;

procedure TFormHeliosMain.FormResize(ASender: TObject);
begin
  if Assigned(LabelHint) then
  begin
    LabelHint.Visible := ClientWidth >= 1100;
  end;
  if Assigned(FScene) and FScene.Initialized then
  begin
    SyncViewportFromPaintBox;
  end;
end;

procedure TFormHeliosMain.DoPaintBoxMouseDown(
  ASender: TObject;
  AButton: TMouseButton;
  AShift: TShiftState;
  AX, AY: Single);
var
  LIndex: Integer;
  LDest: TRectF;
begin
  if not Assigned(FScene) or (AButton <> TMouseButton.mbLeft) then
  begin
    Exit;
  end;
  LDest := GetSceneDrawRect;
  // Clicks in the stats strip are ignored.
  if AY > LDest.Bottom then
  begin
    Exit;
  end;
  LIndex := FScene.HitTestBody(AX, AY, LDest);
  if LIndex >= 0 then
  begin
    FScene.FocusBody(LIndex);
  end
  else
  begin
    FScene.FocusOverview;
  end;
  UpdateStatsFooter;
end;

procedure TFormHeliosMain.DoGameUpdate(const ADeltaTime: Double);
begin
  FScene.Update(ADeltaTime);

  if FStatsHud.ShouldRefresh(ADeltaTime) then
  begin
    UpdateStatsFooter;
  end;
end;

procedure TFormHeliosMain.DoGameRender;
begin
  FStatsHud.OnFrameRendered;
  FPaintBox.Redraw;
end;

procedure TFormHeliosMain.UpdateStatsFooter;
var
  LSpeedDisplay: Integer;
begin
  if not Assigned(FScene) then
  begin
    Exit;
  end;

  // Encode sim speed as an integer percentage of 1× (25 / 100 / 500 / 2000).
  LSpeedDisplay := Round(FScene.SimSpeed * 100);
  if FScene.Paused then
  begin
    LSpeedDisplay := 0;
  end;

  FStatsHud.RefreshText(
    LSpeedDisplay,
    FScene.BodyCount,
    FScene.Time,
    FPaintBox.Width,
    'Speed%',
    'Bodies');
end;

procedure TFormHeliosMain.DoPaintBoxDraw(
  ASender: TObject;
  const ACanvas: ISkCanvas;
  const ADest: TRectF;
  const AOpacity: Single);
var
  LSceneDest: TRectF;
begin
  LSceneDest := ADest;
  LSceneDest.Bottom := Max(ADest.Top + 1, ADest.Bottom - GetStatsHudHeight(ADest.Width));
  THeliosSceneRenderer.Draw(FScene, ACanvas, LSceneDest);
  TStatsHudPainter.Draw(ACanvas, ADest, FStatsHud.Text);
end;

end.
