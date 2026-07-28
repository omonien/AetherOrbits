/// <summary>
/// AetherOrbits.SystemInfo
/// Host/runtime diagnostics: platform, Skia/FMX canvas backend, process CPU.
/// </summary>
///
/// <remarks>
/// Data only — no UI. The stats HUD (AetherOrbits.Stats.Hud) formats and draws
/// these values. Call GetActiveRenderBackendLabel after Application.Initialize
/// and GlobalUseSkia setup.
///
/// Architecture conditionals check iOS before macOS: Delphi defines MACOS on
/// both, so MACOS-first would mislabel iOS devices as macOS.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit AetherOrbits.SystemInfo;

interface

/// <summary>
/// Human-readable host platform (OS + CPU architecture of this binary).
/// Omits build number when TOSVersion.Build is 0 (common on iOS/macOS).
/// </summary>
function GetHostPlatformLabel: string;

/// <summary>
/// Human-readable active rendering backend (Skia Raster/GL/Vulkan/Metal or FMX canvas).
/// Call after Application.Initialize / GlobalUseSkia is applied.
/// </summary>
function GetActiveRenderBackendLabel: string;

/// <summary>
/// FMX display-link preferred frame rate (GlobalPreferredFramesPerSecond).
/// This is a request to the platform, not measured panel Hz.
/// </summary>
function GetPreferredFramesPerSecond: Integer;

/// <summary>
/// Sets GlobalPreferredFramesPerSecond. Caller should restart the game loop
/// (StopLoop/StartLoop) so Mac/iOS CADisplayLink re-applies the range.
/// </summary>
procedure SetPreferredFramesPerSecond(const AValue: Integer);

/// <summary>Number of logical processors visible to this process.</summary>
function GetLogicalProcessorCount: Integer;

/// <summary>
/// Stateful process CPU sampler. First Sample primes and returns 0.
/// </summary>
type
  TProcessCpuSampler = record
  private
    FHasPrior: Boolean;
    FLastWallSeconds: Double;
    FLastProcessSeconds: Double;
    FLastPercentOfOneCore: Double;
    function ReadProcessCpuSeconds: Double;
    function ReadWallSeconds: Double;
  public
    procedure Reset;
    /// <summary>
    /// CPU time used by this process since last Sample, as percent of one logical CPU.
    /// 100 = one core fully busy for the interval. Multi-threaded can exceed 100.
    /// </summary>
    function Sample: Double;
    property LastPercentOfOneCore: Double read FLastPercentOfOneCore;
  end;

implementation

uses
  System.SysUtils,
  System.Types,
  System.Diagnostics,
  FMX.Types,
  FMX.Graphics,
  FMX.Skia,
  FMX.Skia.Canvas,
{$IF Defined(MSWINDOWS)}
  Winapi.Windows
{$ELSEIF Defined(POSIX)}
  Posix.Base,
  Posix.SysTypes,
  Posix.SysTimes,
  Posix.Unistd
{$ENDIF}
  ;

var
  GWallClock: TStopwatch;

{ Platform }

function GetArchitectureLabel: string;
begin
  // iOS before macOS: on iOS targets Delphi also defines MACOS.
{$IF Defined(IOS64)}
  Result := 'iOS ARM64';
{$ELSEIF Defined(IOS32)}
  Result := 'iOS ARM';
{$ELSEIF Defined(IOS) and Defined(CPUARM64)}
  Result := 'iOS ARM64';
{$ELSEIF Defined(IOS) and Defined(CPUARM)}
  Result := 'iOS ARM';
{$ELSEIF Defined(IOS)}
  Result := 'iOS';
{$ELSEIF Defined(WIN64)}
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
{$ELSEIF Defined(ANDROID)}
  Result := 'Android';
{$ELSE}
  Result := 'UnknownArch';
{$ENDIF}
end;

function GetHostPlatformLabel: string;
var
  LOs: string;
begin
  // TOSVersion.Build is reliable on Windows; often 0 on iOS/macOS — omit then.
  LOs := Format('%s %d.%d', [TOSVersion.Name, TOSVersion.Major, TOSVersion.Minor]);
  if TOSVersion.Build > 0 then
  begin
    LOs := LOs + Format(' (build %d)', [TOSVersion.Build]);
  end;
  Result := Format('%s - %s', [GetArchitectureLabel, LOs]);
end;

{ Skia / FMX canvas backend }

function FriendlyCanvasClassName(const AClass: TClass): string;
var
  LName: string;
begin
  if AClass = nil then
  begin
    Exit('(none)');
  end;

  LName := AClass.ClassName;

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

  if GlobalUseSkia then
  begin
    LSkiaClass := DefaultSkiaRenderCanvasClass;
    if LSkiaClass <> nil then
    begin
      Exit(FriendlyCanvasClassName(LSkiaClass) + LFlags);
    end;
  end;

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

{ Preferred frames per second }

function GetPreferredFramesPerSecond: Integer;
begin
  Result := GlobalPreferredFramesPerSecond;
  if Result < 1 then
  begin
    Result := 60;
  end;
end;

procedure SetPreferredFramesPerSecond(const AValue: Integer);
begin
  if AValue < 1 then
  begin
    GlobalPreferredFramesPerSecond := 60;
  end
  else
  begin
    GlobalPreferredFramesPerSecond := AValue;
  end;
end;

{ CPU }

function GetLogicalProcessorCount: Integer;
begin
  Result := CPUCount;
  if Result < 1 then
  begin
    Result := 1;
  end;
end;

function TProcessCpuSampler.ReadWallSeconds: Double;
begin
  if not GWallClock.IsRunning then
  begin
    GWallClock := TStopwatch.StartNew;
  end;
  Result := GWallClock.Elapsed.TotalSeconds;
end;

function TProcessCpuSampler.ReadProcessCpuSeconds: Double;
{$IF Defined(MSWINDOWS)}
var
  LCreation, LExit, LKernel, LUser: TFileTime;
  LKernel64, LUser64: UInt64;
begin
  if not GetProcessTimes(GetCurrentProcess, LCreation, LExit, LKernel, LUser) then
  begin
    Exit(0);
  end;
  LKernel64 := UInt64(LKernel.dwLowDateTime) or (UInt64(LKernel.dwHighDateTime) shl 32);
  LUser64 := UInt64(LUser.dwLowDateTime) or (UInt64(LUser.dwHighDateTime) shl 32);
  Result := (LKernel64 + LUser64) / 1.0E7;
end;
{$ELSEIF Defined(POSIX)}
var
  LTms: tms;
  LTicksPerSec: LongInt;
  LTicks: clock_t;
begin
  FillChar(LTms, SizeOf(LTms), 0);
  LTicks := times(LTms);
  if LTicks = clock_t(-1) then
  begin
    Exit(0);
  end;

  LTicksPerSec := sysconf(_SC_CLK_TCK);
  if LTicksPerSec <= 0 then
  begin
    LTicksPerSec := 100;
  end;

  Result := (Double(LTms.tms_utime) + Double(LTms.tms_stime)) / Double(LTicksPerSec);
end;
{$ELSE}
begin
  Result := 0;
end;
{$ENDIF}

procedure TProcessCpuSampler.Reset;
begin
  FHasPrior := False;
  FLastWallSeconds := 0;
  FLastProcessSeconds := 0;
  FLastPercentOfOneCore := 0;
  if not GWallClock.IsRunning then
  begin
    GWallClock := TStopwatch.StartNew;
  end;
end;

function TProcessCpuSampler.Sample: Double;
var
  LWall: Double;
  LProc: Double;
  LWallDelta: Double;
  LProcDelta: Double;
begin
  LWall := ReadWallSeconds;
  LProc := ReadProcessCpuSeconds;

  if not FHasPrior then
  begin
    FHasPrior := True;
    FLastWallSeconds := LWall;
    FLastProcessSeconds := LProc;
    FLastPercentOfOneCore := 0;
    Exit(0);
  end;

  LWallDelta := LWall - FLastWallSeconds;
  LProcDelta := LProc - FLastProcessSeconds;
  FLastWallSeconds := LWall;
  FLastProcessSeconds := LProc;

  if LWallDelta <= 1.0E-6 then
  begin
    Exit(FLastPercentOfOneCore);
  end;

  if LProcDelta < 0 then
  begin
    LProcDelta := 0;
  end;

  Result := 100.0 * (LProcDelta / LWallDelta);
  FLastPercentOfOneCore := Result;
end;

initialization
  GWallClock := TStopwatch.StartNew;

end.