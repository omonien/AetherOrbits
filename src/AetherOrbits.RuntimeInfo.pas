/// <summary>
/// AetherOrbits.RuntimeInfo
/// Host platform and active FMX/Skia canvas backend labels for diagnostics.
/// </summary>
///
/// <remarks>
/// Reports what is actually registered as the default render canvas after
/// GlobalUseSkia initialization — not a hard-coded assumption about GPU.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit AetherOrbits.RuntimeInfo;

interface

/// <summary>
/// Human-readable host platform (OS + CPU architecture of this binary).
/// </summary>
function GetHostPlatformLabel: string;

/// <summary>
/// Human-readable active rendering backend (Skia Raster/GL/Vulkan/Metal or FMX canvas).
/// Call after Application.Initialize / GlobalUseSkia is applied.
/// </summary>
function GetActiveRenderBackendLabel: string;

implementation

uses
  System.SysUtils,
  System.Types,
  FMX.Types,
  FMX.Graphics,
  FMX.Skia,
  FMX.Skia.Canvas;

function GetArchitectureLabel: string;
begin
  // Prefer OS+bitness conditionals that Delphi sets for each target
{$IF Defined(WIN64)}
  Result := 'Win64';
{$ELSEIF Defined(WIN32)}
  Result := 'Win32';
{$ELSEIF Defined(MACOS) and Defined(CPUARM64)}
  Result := 'macOS ARM64';
{$ELSEIF Defined(MACOS) and Defined(CPUX64)}
  Result := 'macOS x64';
{$ELSEIF Defined(MACOS64) or Defined(OSX64)}
  Result := 'macOS64';
{$ELSEIF Defined(LINUX64)}
  Result := 'Linux64';
{$ELSEIF Defined(ANDROID64)}
  Result := 'Android64';
{$ELSEIF Defined(ANDROID32)}
  Result := 'Android32';
{$ELSEIF Defined(IOS64)}
  Result := 'iOS64';
{$ELSEIF Defined(IOS32)}
  Result := 'iOS32';
{$ELSEIF Defined(IOS)}
  Result := 'iOS';
{$ELSEIF Defined(ANDROID)}
  Result := 'Android';
{$ELSE}
  Result := 'UnknownArch';
{$ENDIF}
end;

function GetHostPlatformLabel: string;
begin
  // Architecture of this binary + OS identity (English API field names)
  Result := Format('%s - %s %d.%d (build %d)',
    [GetArchitectureLabel, TOSVersion.Name, TOSVersion.Major, TOSVersion.Minor, TOSVersion.Build]);
end;

function FriendlyCanvasClassName(const AClass: TClass): string;
var
  LName: string;
begin
  if AClass = nil then
  begin
    Exit('(none)');
  end;

  LName := AClass.ClassName;

  // Skia backends (class names from FMX.Skia.Canvas.*)
  if LName.Contains('Raster') then
  begin
    Exit('Skia Raster (CPU)');
  end;
  if LName.Contains('Gl') or LName.Contains('GL') then
  begin
    Exit('Skia OpenGL (GPU)');
  end;
  if LName.Contains('Vk') or LName.Contains('Vulkan') then
  begin
    Exit('Skia Vulkan (GPU)');
  end;
  if LName.Contains('Mtl') or LName.Contains('Metal') then
  begin
    Exit('Skia Metal (GPU)');
  end;

  if GlobalUseSkia then
  begin
    Result := Format('Skia (%s)', [LName]);
  end
  else
  begin
    Result := Format('FMX (%s)', [LName]);
  end;
end;

function GetActiveRenderBackendLabel: string;
var
  LSkiaClass: TSkCanvasBaseClass;
  LCanvasClass: TCanvasClass;
  LFlags: string;
begin
  LFlags := '';
  if GlobalUseSkia then
  begin
    LFlags := LFlags + ' Skia=on';
  end;
{$IF Defined(MACOS) or Defined(IOS)}
  if GlobalUseMetal then
  begin
    LFlags := LFlags + ' Metal=on';
  end
  else
  begin
    LFlags := LFlags + ' Metal=off';
  end;
{$ENDIF}
  if GlobalUseSkiaRasterWhenAvailable then
  begin
    LFlags := LFlags + ' PreferRaster';
  end;

  // Prefer the Skia render-canvas class actually selected at registration
  if GlobalUseSkia then
  begin
    LSkiaClass := DefaultSkiaRenderCanvasClass;
    if LSkiaClass <> nil then
    begin
      Exit(FriendlyCanvasClassName(LSkiaClass) + LFlags);
    end;
  end;

  // Fallback: FMX canvas manager default (post-registration)
  LCanvasClass := TCanvasManager.DefaultCanvas;
  if LCanvasClass <> nil then
  begin
    Exit(FriendlyCanvasClassName(LCanvasClass) + LFlags);
  end;

  if GlobalUseSkia then
  begin
    Result := 'Skia (pending registration)' + LFlags;
  end
  else
  begin
    Result := 'FMX (default)' + LFlags;
  end;
end;

end.