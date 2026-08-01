/// <summary>
/// Helios
/// FMX + Skia soft-3D solar-system demo (second Aether game-loop showcase).
/// </summary>
///
/// <remarks>
/// Same frame pipeline as Aether Orbits: TGameLoop (Display Link) drives
/// THeliosScene; Skia draws a perspective projection. Startup flags match
/// AetherOrbits (Skia GPU path, Metal on Apple).
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

program Helios;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Types,
  FMX.Skia,
  Helios.Main.Form in 'Helios.Main.Form.pas' {FormHeliosMain},
  Helios.Scene in 'Helios.Scene.pas',
  Helios.Scene.Renderer in 'Helios.Scene.Renderer.pas',
  FMXAnimation.GameLoop in '..\FMXAnimation.GameLoop.pas',
  FMXAnimation.SystemInfo in '..\FMXAnimation.SystemInfo.pas',
  FMXAnimation.Stats.Hud in '..\FMXAnimation.Stats.Hud.pas',
  FMXAnimation.DemoShell in '..\FMXAnimation.DemoShell.pas';

{$R *.res}

begin
  GlobalUseSkia := True;
  GlobalUseSkiaRasterWhenAvailable := False;

{$IF Defined(MACOS) or Defined(IOS)}
  GlobalUseMetal := True;
{$ENDIF}

  Application.Initialize;
  Application.CreateForm(TFormHeliosMain, FormHeliosMain);
  Application.Run;
end.
