/// <summary>
/// AetherOrbits.Main.Form
/// Aether Orbits demo scene – atmospheric orbs and particles via FMX + Skia.
/// </summary>
///
/// <remarks>
/// Demonstrates TGameLoop (AetherOrbits.GameLoop) driving a Skia paint box
/// with fixed-timestep updates and once-per-frame redraw.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit AetherOrbits.Main.Form;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Math, System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  System.Skia, FMX.Skia,
  AetherOrbits.GameLoop;

type
  TParticle = record
    Pos: TPointF;
    Vel: TPointF;
    Life: Single;
    MaxLife: Single;
    Size: Single;
    Hue: Single;
  end;

  TOrb = record
    Angle: Single;
    Radius: Single;
    Speed: Single;
    Size: Single;
    BaseSize: Single;
    Color: TAlphaColor;
    Phase: Single;
  end;

  TFormMain = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
  private
    FSkPaintBox: TSkPaintBox;
    FGameLoop: TGameLoop;
    FParticles: TList<TParticle>;
    FOrbs: TArray<TOrb>;
    FTime: Double;
    FMouse: TPointF;
    FCenter: TPointF;
    FFrameCount: Integer;
    FFpsTimer: Double;
    FFps: Integer;

    procedure InitScene;
    procedure OnGameUpdate(const ADeltaTime: Double);
    procedure OnGameRender;
    procedure SpawnParticle(const ANear: TPointF; const AForce: Single = 0);
    procedure SkPaintBoxDraw(ASender: TObject; const ACanvas: ISkCanvas;
      const ADest: TRectF; const AOpacity: Single);
  public
  end;

var
  FormMain: TFormMain;

implementation

{$R *.fmx}

procedure TFormMain.FormCreate(Sender: TObject);
begin
  // Full-client Skia paint box
  FSkPaintBox := TSkPaintBox.Create(Self);
  FSkPaintBox.Parent := Self;
  FSkPaintBox.Align := TAlignLayout.Client;
  FSkPaintBox.OnDraw := SkPaintBoxDraw;

  FParticles := TList<TParticle>.Create;
  FMouse := TPointF.Create(ClientWidth / 2, ClientHeight / 2);

  InitScene;

  // Core: VSync-driven game loop
  FGameLoop := TGameLoop.Create(Self);
  FGameLoop.OnUpdate := OnGameUpdate;
  FGameLoop.OnRender := OnGameRender;
  FGameLoop.StartLoop;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  FGameLoop.StopLoop;
  FParticles.Free;
end;

procedure TFormMain.InitScene;
begin
  SetLength(FOrbs, 5);

  FOrbs[0].Radius := 140; FOrbs[0].Speed :=  0.35; FOrbs[0].BaseSize := 28;
  FOrbs[0].Color := $FF00E5FF; FOrbs[0].Phase := 0.0;

  FOrbs[1].Radius := 210; FOrbs[1].Speed := -0.22; FOrbs[1].BaseSize := 18;
  FOrbs[1].Color := $FFFF2E9F; FOrbs[1].Phase := 1.2;

  FOrbs[2].Radius := 280; FOrbs[2].Speed :=  0.15; FOrbs[2].BaseSize := 22;
  FOrbs[2].Color := $FFFFD166; FOrbs[2].Phase := 2.8;

  FOrbs[3].Radius := 175; FOrbs[3].Speed := -0.41; FOrbs[3].BaseSize := 14;
  FOrbs[3].Color := $FF7B61FF; FOrbs[3].Phase := 4.1;

  FOrbs[4].Radius := 320; FOrbs[4].Speed :=  0.09; FOrbs[4].BaseSize := 16;
  FOrbs[4].Color := $FF00FFA3; FOrbs[4].Phase := 0.7;

  for var i := 0 to High(FOrbs) do
  begin
    FOrbs[i].Angle := Random * Pi * 2;
    FOrbs[i].Size := FOrbs[i].BaseSize;
  end;

  for var i := 0 to 120 do
    SpawnParticle(TPointF.Create(ClientWidth * Random, ClientHeight * Random), 0.3);
end;

procedure TFormMain.SpawnParticle(const ANear: TPointF; const AForce: Single);
var
  P: TParticle;
  Angle: Single;
begin
  Angle := Random * Pi * 2;
  P.Pos := ANear + TPointF.Create(Cos(Angle) * Random * 40, Sin(Angle) * Random * 40);
  P.Vel := TPointF.Create((Random - 0.5) * 40 * AForce, (Random - 0.5) * 40 * AForce);
  P.MaxLife := 1.8 + Random * 2.5;
  P.Life := P.MaxLife;
  P.Size := 1.2 + Random * 2.8;
  P.Hue := Random;
  FParticles.Add(P);
end;

procedure TFormMain.OnGameUpdate(const ADeltaTime: Double);
var
  i: Integer;
  P: TParticle;
  OrbPos: TPointF;
  Dist: Single;
  Force: TPointF;
begin
  FTime := FTime + ADeltaTime;
  FCenter := TPointF.Create(ClientWidth * 0.5, ClientHeight * 0.5);

  // Orbs
  for i := 0 to High(FOrbs) do
  begin
    FOrbs[i].Angle := FOrbs[i].Angle + FOrbs[i].Speed * ADeltaTime;
    FOrbs[i].Size := FOrbs[i].BaseSize * (1 + 0.12 * Sin(FTime * 2.1 + FOrbs[i].Phase));
  end;

  // Particles
  for i := FParticles.Count - 1 downto 0 do
  begin
    P := FParticles[i];
    P.Life := P.Life - ADeltaTime;

    if P.Life <= 0 then
    begin
      FParticles.Delete(i);
      Continue;
    end;

    Dist := P.Pos.Distance(FMouse);
    if Dist < 180 then
    begin
      Force := (P.Pos - FMouse).Normalize * (1 - Dist / 180) * 28;
      P.Vel := P.Vel + Force * ADeltaTime;
    end;

    P.Vel := P.Vel + (FCenter - P.Pos).Normalize * 4 * ADeltaTime;
    P.Vel := P.Vel * (1 - 0.85 * ADeltaTime);
    P.Pos := P.Pos + P.Vel * ADeltaTime;

    FParticles[i] := P;
  end;

  // Spawn new particles from orbs
  if Random < 0.35 then
  begin
    i := Random(Length(FOrbs));
    OrbPos := FCenter + TPointF.Create(
      Cos(FOrbs[i].Angle) * FOrbs[i].Radius,
      Sin(FOrbs[i].Angle) * FOrbs[i].Radius * 0.72);
    SpawnParticle(OrbPos, 0.6);
  end;

  // FPS counter
  Inc(FFrameCount);
  FFpsTimer := FFpsTimer + ADeltaTime;
  if FFpsTimer >= 1.0 then
  begin
    FFps := FFrameCount;
    FFrameCount := 0;
    FFpsTimer := 0;
  end;
end;

procedure TFormMain.OnGameRender;
begin
  // Invalidate only – drawing happens in OnDraw
  FSkPaintBox.Redraw;
end;

procedure TFormMain.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
begin
  FMouse := TPointF.Create(X, Y);
end;

procedure TFormMain.SkPaintBoxDraw(ASender: TObject; const ACanvas: ISkCanvas;
  const ADest: TRectF; const AOpacity: Single);
var
  Paint: ISkPaint;
  i: Integer;
  OrbPos: TPointF;
  Alpha, R, CorePulse: Single;
begin
  // Background
  Paint := TSkPaint.Create;
  Paint.Shader := TSkShader.MakeGradientRadial(
    ADest.CenterPoint, ADest.Width * 0.75,
    [$FF070B14, $FF0F1629, $FF1A243F]);
  ACanvas.DrawPaint(Paint);

  // Central core
  CorePulse := 1 + 0.08 * Sin(FTime * 1.7);
  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;

  Paint.Color := TAlphaColorF.Create(0.1, 0.4, 0.9, 0.12).ToAlphaColor;
  ACanvas.DrawCircle(FCenter.X, FCenter.Y, 95 * CorePulse, Paint);

  Paint.Color := TAlphaColorF.Create(0.2, 0.55, 1.0, 0.25).ToAlphaColor;
  ACanvas.DrawCircle(FCenter.X, FCenter.Y, 55 * CorePulse, Paint);

  Paint.Shader := TSkShader.MakeGradientRadial(FCenter, 38 * CorePulse,
    [$FFFFFFFF, $FF66B3FF, $FF1A6BFF, $00000000]);
  ACanvas.DrawCircle(FCenter.X, FCenter.Y, 38 * CorePulse, Paint);

  // Orbs
  for i := 0 to High(FOrbs) do
  begin
    OrbPos := FCenter + TPointF.Create(
      Cos(FOrbs[i].Angle) * FOrbs[i].Radius,
      Sin(FOrbs[i].Angle) * FOrbs[i].Radius * 0.72);

    Paint := TSkPaint.Create;
    Paint.AntiAlias := True;

    // Glow layers
    Paint.Color := TAlphaColorF.Create(
      TAlphaColorRec(FOrbs[i].Color).R / 255,
      TAlphaColorRec(FOrbs[i].Color).G / 255,
      TAlphaColorRec(FOrbs[i].Color).B / 255, 0.08).ToAlphaColor;
    ACanvas.DrawCircle(OrbPos.X, OrbPos.Y, FOrbs[i].Size * 2.8, Paint);

    Paint.Color := TAlphaColorF.Create(
      TAlphaColorRec(FOrbs[i].Color).R / 255,
      TAlphaColorRec(FOrbs[i].Color).G / 255,
      TAlphaColorRec(FOrbs[i].Color).B / 255, 0.18).ToAlphaColor;
    ACanvas.DrawCircle(OrbPos.X, OrbPos.Y, FOrbs[i].Size * 1.7, Paint);

    Paint.Color := FOrbs[i].Color;
    ACanvas.DrawCircle(OrbPos.X, OrbPos.Y, FOrbs[i].Size, Paint);

    // Highlight
    Paint.Color := TAlphaColorF.Create(1, 1, 1, 0.55).ToAlphaColor;
    ACanvas.DrawCircle(
      OrbPos.X - FOrbs[i].Size * 0.25,
      OrbPos.Y - FOrbs[i].Size * 0.25,
      FOrbs[i].Size * 0.35, Paint);
  end;

  // Particles
  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;

  for i := 0 to FParticles.Count - 1 do
  begin
    Alpha := FParticles[i].Life / FParticles[i].MaxLife;
    Alpha := Alpha * Alpha;
    R := FParticles[i].Size * (0.6 + 0.4 * Alpha);

    case Trunc(FParticles[i].Hue * 4) of
      0: Paint.Color := TAlphaColorF.Create(0.3, 0.85, 1.0, Alpha * 0.7).ToAlphaColor;
      1: Paint.Color := TAlphaColorF.Create(1.0, 0.4, 0.75, Alpha * 0.65).ToAlphaColor;
      2: Paint.Color := TAlphaColorF.Create(1.0, 0.85, 0.4, Alpha * 0.6).ToAlphaColor;
    else
      Paint.Color := TAlphaColorF.Create(0.7, 0.55, 1.0, Alpha * 0.65).ToAlphaColor;
    end;

    ACanvas.DrawCircle(FParticles[i].Pos.X, FParticles[i].Pos.Y, R, Paint);
  end;
end;

end.