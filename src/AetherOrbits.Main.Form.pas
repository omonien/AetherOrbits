/// <summary>
/// AetherOrbits.Main.Form
/// Thin FMX shell for the Aether Orbits demo.
/// </summary>
///
/// <remarks>
/// Wires TGameLoop to TAetherScene and a TSkPaintBox. System diagnostics live
/// in AetherOrbits.SystemInfo; the stats overlay is AetherOrbits.Stats.Hud.
/// Preferred FPS segment control sets GlobalPreferredFramesPerSecond and
/// restarts the game loop so Mac/iOS Display Link re-applies the range.
/// The bar uses dark Skia-matching chrome (rectangles), not light theme panels.
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
  System.Math,
  // FMX
  FMX.Types,
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.StdCtrls,
  FMX.Layouts,
  FMX.Objects,
  FMX.Forms,
  FMX.Graphics,
  // Skia
  System.Skia,
  FMX.Skia,
  // Own
  AetherOrbits.GameLoop,
  AetherOrbits.Scene,
  AetherOrbits.Scene.Renderer,
  AetherOrbits.Stats.Hud,
  AetherOrbits.SystemInfo;

type
  /// <summary>
  /// Main demo window: game loop + scene + Skia paint box + stats HUD.
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
    procedure FormMouseMove(ASender: TObject; AShift: TShiftState; AX, AY: Single);
    procedure FormResize(ASender: TObject);
    procedure PreferredSegClick(ASender: TObject);
  private
    FPaintBox: TSkPaintBox;
    FGameLoop: TGameLoop;
    FScene: TAetherScene;
    FStatsHud: TStatsHudModel;
    FApplyingPreferred: Boolean;

    procedure CreateUi;
    procedure StylePreferredSegment(const ARect: TRectangle; const ALabel: TLabel;
      const ASelected: Boolean);
    procedure SyncPreferredSegmentsFromGlobal;
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
    procedure UpdateStatsFooter;
    procedure ApplyPreferredFps(const AFps: Integer; const ARestartLoop: Boolean);
  end;

var
  FormMain: TFormMain;

implementation

{$R *.fmx}

const
  // Match stats HUD chrome (AetherOrbits.Stats.Hud).
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

{ TFormMain }

procedure TFormMain.StylePreferredSegment(
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
    StylePreferredSegment(RectSeg30, LabelSeg30, LFps = 30);
    StylePreferredSegment(RectSeg60, LabelSeg60, LFps = 60);
    StylePreferredSegment(RectSeg120, LabelSeg120, LFps = 120);
  finally
    FApplyingPreferred := False;
  end;
end;

procedure TFormMain.CreateUi;
begin
  // Paint box lives only in LayoutScene (Align=Client). Never parent it to the
  // form with Align=Client — that can cover LayoutPreferred in z-order.
  FPaintBox := TSkPaintBox.Create(Self);
  FPaintBox.Parent := LayoutScene;
  FPaintBox.Align := TAlignLayout.Client;
  FPaintBox.HitTest := False;
  FPaintBox.OnDraw := DoPaintBoxDraw;

  // Ensure bar colors survive platform style injection.
  RectPreferredBg.Fill.Color := cBarBg;
  RectPreferredBottomLine.Fill.Color := cBarLine;
  LabelPreferred.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  LabelPreferred.TextSettings.FontColor := cLabelMuted;
  LabelPreferredHint.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  LabelPreferredHint.TextSettings.FontColor := cHintMuted;
  LabelSeg30.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  LabelSeg60.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];
  LabelSeg120.StyledSettings := [TStyledSetting.Family, TStyledSetting.Style];

  // Small gaps between segment chips (Align=Left otherwise packs flush).
  RectSeg60.Margins.Left := 8;
  RectSeg120.Margins.Left := 8;

  LayoutPreferred.Visible := True;
  LayoutPreferred.BringToFront;
  // Hint is desktop-only clutter on phones.
  LabelPreferredHint.Visible := ClientWidth >= 640;
  SyncPreferredSegmentsFromGlobal;
end;

function TFormMain.GetSceneViewportHeight: Single;
begin
  Result := Max(1, FPaintBox.Height - GetStatsHudHeight(FPaintBox.Width));
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

procedure TFormMain.ApplyPreferredFps(const AFps: Integer; const ARestartLoop: Boolean);
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
    // Mac/iOS CADisplayLink applies preferred range on Subscribe — restart loop.
    // Windows DWM still needs GameLoop Preferred pacing (see AetherOrbits.GameLoop).
    LWasRunning := FGameLoop.Running;
    FGameLoop.StopLoop;
    if LWasRunning or Visible then
    begin
      FGameLoop.StartLoop;
    end;
  end;

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

  ApplyPreferredFps(LFps, True);
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

procedure TFormMain.FormMouseMove(ASender: TObject; AShift: TShiftState; AX, AY: Single);
var
  LLocal: TPointF;
begin
  if not Assigned(FScene) or not Assigned(FPaintBox) then
  begin
    Exit;
  end;
  // Form client → screen → paint-box local (preferred bar sits above LayoutScene).
  LLocal := FPaintBox.ScreenToLocal(ClientToScreen(TPointF.Create(AX, AY)));
  if FPaintBox.LocalRect.Contains(LLocal) then
  begin
    FScene.SetMousePosition(LLocal);
  end;
end;

procedure TFormMain.DoGameUpdate(const ADeltaTime: Double);
begin
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
var
  LSceneDest: TRectF;
begin
  LSceneDest := ADest;
  LSceneDest.Bottom := Max(ADest.Top + 1, ADest.Bottom - GetStatsHudHeight(ADest.Width));
  TAetherSceneRenderer.Draw(FScene, ACanvas, LSceneDest);
  TStatsHudPainter.Draw(ACanvas, ADest, FStatsHud.Text);
end;

end.
