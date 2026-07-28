/// <summary>
/// AetherOrbits
/// FMX + Skia game-loop demo application.
/// </summary>
///
/// <remarks>
/// Thin shell: TGameLoop (Display Link / ProcessAnimation) drives TAetherScene;
/// Skia is only the efficient draw backend (not the game-loop black box).
/// Requires Delphi 13+ with integrated Skia.
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
  AetherOrbits.GameLoop in 'AetherOrbits.GameLoop.pas',
  AetherOrbits.Scene in 'AetherOrbits.Scene.pas',
  AetherOrbits.Scene.Renderer in 'AetherOrbits.Scene.Renderer.pas',
  AetherOrbits.RuntimeInfo in 'AetherOrbits.RuntimeInfo.pas';

{$R *.res}

begin
  GlobalUseSkia := True;
  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
