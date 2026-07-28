/// <summary>
/// AetherOrbits
/// FMX + Skia game-loop demo application.
/// </summary>
///
/// <remarks>
/// Atmospheric particle/orb demo driven by TGameLoop (VSync via TAnimation
/// Display Link). Requires Delphi 13+ with integrated Skia.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

program AetherOrbits;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Skia,
  AetherOrbits.Main.Form in 'AetherOrbits.Main.Form.pas' {FormMain},
  AetherOrbits.GameLoop in 'AetherOrbits.GameLoop.pas';

{$R *.res}

begin
  GlobalUseSkia := True;
  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.