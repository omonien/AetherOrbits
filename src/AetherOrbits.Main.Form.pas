/// <summary>
/// AetherOrbits.Main.Form
/// Thin FMX shell for the Aether Orbits demo.
/// </summary>
///
/// <remarks>
/// Owns UI (form + Skia paint box) and wires the standalone TGameLoop to TAetherScene.
/// TGameLoop (AetherOrbits.GameLoop) knows nothing about this form or the scene;
/// its core is the ProcessAnimation override (FMX Display Link / Delphi 13).
/// Simulation lives in AetherOrbits.Scene; drawing in AetherOrbits.Scene.Renderer.
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
  AetherOrbits.Scene.Renderer;

type
  /// <summary>
  /// Main demo window: game loop + scene + paint box only.
  /// </summary>
  TFormMain = class(TForm)
    procedure FormCreate(ASender: TObject);
    procedure FormDestroy(ASender: TObject);
    procedure FormMouseMove(ASender: TObject; AShift: TShiftState; AX, AY: Single);
    procedure FormResize(ASender: TObject);
  private
    FPaintBox: TSkPaintBox;
    FGameLoop: TGameLoop;
    FScene: TAetherScene;

    procedure DoGameUpdate(const ADeltaTime: Double);
    procedure DoGameRender;
    procedure DoPaintBoxDraw(
      ASender: TObject;
      const ACanvas: ISkCanvas;
      const ADest: TRectF;
      const AOpacity: Single);
  end;

var
  FormMain: TFormMain;

implementation

{$R *.fmx}

{ TFormMain }

procedure TFormMain.FormCreate(ASender: TObject);
begin
  FScene := TAetherScene.Create;

  FPaintBox := TSkPaintBox.Create(Self);
  FPaintBox.Parent := Self;
  FPaintBox.Align := TAlignLayout.Client;
  FPaintBox.HitTest := False;
  FPaintBox.OnDraw := DoPaintBoxDraw;

  FScene.Initialize(ClientWidth, ClientHeight);

  FGameLoop := TGameLoop.Create(Self);
  FGameLoop.OnUpdate := DoGameUpdate;
  FGameLoop.OnRender := DoGameRender;
  FGameLoop.StartLoop;
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
    FScene.SetViewport(ClientWidth, ClientHeight);
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
  FScene.SetViewport(ClientWidth, ClientHeight);
  FScene.Update(ADeltaTime);
end;

procedure TFormMain.DoGameRender;
begin
  FPaintBox.Redraw;
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