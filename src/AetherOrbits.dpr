/// <summary>
/// AetherOrbits
/// FMX + Skia game-loop demo application.
/// </summary>
///
/// <remarks>
/// Thin shell: TGameLoop (Display Link / ProcessAnimation) drives TAetherScene;
/// Skia is the drawing API. Startup must set more than GlobalUseSkia:
/// Windows: GlobalUseSkiaRasterWhenAvailable := False (else CPU raster is preferred);
/// macOS/iOS: GlobalUseMetal := True (else Metal canvas is not offered).
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
  FMX.Types,
  FMX.Skia,
  AetherOrbits.Main.Form in 'AetherOrbits.Main.Form.pas' {FormMain},
  AetherOrbits.GameLoop in 'AetherOrbits.GameLoop.pas',
  AetherOrbits.Scene in 'AetherOrbits.Scene.pas',
  AetherOrbits.Scene.Renderer in 'AetherOrbits.Scene.Renderer.pas',
  AetherOrbits.RuntimeInfo in 'AetherOrbits.RuntimeInfo.pas';

{$R *.res}

begin
  // GlobalUseSkia alone is not enough:
  // - Windows defaults PreferRaster=True → Skia Raster (CPU) unless set False
  // - then OpenGL (or Vulkan) can become the active form canvas
  GlobalUseSkia := True;
  GlobalUseSkiaRasterWhenAvailable := False;

  // macOS: GlobalUseMetal defaults to False (iOS defaults to True).
  // TMtlCanvas is only offered to Skia when GlobalUseMetal is True; otherwise
  // the app falls back to Skia Raster (CPU) — typically single-digit FPS for
  // full-window particle demos (as observed on Intel Mac via PAServer).
{$IF Defined(MACOS) or Defined(IOS)}
  GlobalUseMetal := True;
{$ENDIF}

  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.