/// <summary>
/// AetherOrbits.Main.Form
/// Thin FMX shell for the Aether Orbits demo.
/// </summary>
///
/// <remarks>
/// Wires TGameLoop to TAetherScene and a TSkPaintBox. System diagnostics live
/// in AetherOrbits.SystemInfo; the stats overlay is AetherOrbits.Stats.Hud.
/// Preferred FPS radios set GlobalPreferredFramesPerSecond and restart the
/// game loop so Mac/iOS Display Link re-applies the range.
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
    PanelPreferred: TPanel;
    LabelPreferred: TLabel;
    LayoutPreferredRadios: TLayout;
    RadioPreferred30: TRadioButton;
    RadioPreferred60: TRadioButton;
    RadioPreferred120: TRadioButton;
    LayoutScene: TLayout;
    procedure FormCreate(ASender: TObject);
    procedure FormDestroy(ASender: TObject);
    procedure FormShow(ASender: TObject);
    procedure FormMouseMove(ASender: TObject; AShift: TShiftState; AX, AY: Single);
    procedure FormResize(ASender: TObject);
    procedure RadioPreferredChange(ASender: TObject);
  private
    FPaintBox: TSkPaintBox;
    FGameLoop: TGameLoop;
    FScene: TAetherScene;
    FStatsHud: TStatsHudModel;
    FApplyingPreferred: Boolean;

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
    procedure UpdateStatsFooter;
    procedure SyncPreferredRadiosFromGlobal;
    procedure ApplyPreferredFps(const AFps: Integer; const ARestartLoop: Boolean);
  end;

var
  FormMain: TFormMain;

implementation

{$R *.fmx}

{ TFormMain }

procedure TFormMain.CreateUi;
begin
  // Paint box lives only in LayoutScene (Align=Client). Never parent it to the
  // form with Align=Client — that can cover PanelPreferred in z-order.
  FPaintBox := TSkPaintBox.Create(Self);
  FPaintBox.Parent := LayoutScene;
  FPaintBox.Align := TAlignLayout.Client;
  FPaintBox.HitTest := False;
  FPaintBox.OnDraw := DoPaintBoxDraw;

  PanelPreferred.Visible := True;
  PanelPreferred.BringToFront;
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

procedure TFormMain.SyncPreferredRadiosFromGlobal;
var
  LFps: Integer;
begin
  LFps := GetPreferredFramesPerSecond;
  FApplyingPreferred := True;
  try
    RadioPreferred30.IsChecked := LFps = 30;
    RadioPreferred60.IsChecked := LFps = 60;
    RadioPreferred120.IsChecked := LFps = 120;
    // Unknown value (e.g. 90): fall back visually to 60 without writing global.
    if not (RadioPreferred30.IsChecked or RadioPreferred60.IsChecked or
      RadioPreferred120.IsChecked) then
    begin
      RadioPreferred60.IsChecked := True;
    end;
  finally
    FApplyingPreferred := False;
  end;
end;

procedure TFormMain.ApplyPreferredFps(const AFps: Integer; const ARestartLoop: Boolean);
var
  LWasRunning: Boolean;
begin
  if GetPreferredFramesPerSecond = AFps then
  begin
    Exit;
  end;

  SetPreferredFramesPerSecond(AFps);

  if ARestartLoop and Assigned(FGameLoop) then
  begin
    // Mac/iOS CADisplayLink applies preferred range on Subscribe — restart loop.
    LWasRunning := FGameLoop.Running;
    FGameLoop.StopLoop;
    if LWasRunning or Visible then
    begin
      FGameLoop.StartLoop;
    end;
  end;

  UpdateStatsFooter;
end;

procedure TFormMain.RadioPreferredChange(ASender: TObject);
var
  LFps: Integer;
begin
  if FApplyingPreferred then
  begin
    Exit;
  end;
  if not (ASender is TRadioButton) then
  begin
    Exit;
  end;
  if not TRadioButton(ASender).IsChecked then
  begin
    Exit;
  end;

  if ASender = RadioPreferred30 then
    LFps := 30
  else if ASender = RadioPreferred120 then
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

  // Radios default to 60 in the FMX; keep UI in sync if global was pre-set.
  SyncPreferredRadiosFromGlobal;

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
  // Form client → screen → paint-box local (panel sits above LayoutScene).
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
