/// <summary>
/// AetherOrbits.ProcessCpu
/// Samples this process CPU usage for the stats footer.
/// </summary>
///
/// <remarks>
/// Reports percent of one logical CPU (can exceed 100 if the process uses
/// multiple cores). Also exposes logical CPU count so the footer can show
/// "of machine" as percent / core count.
/// Windows: GetProcessTimes. POSIX (macOS/Linux): getrusage(RUSAGE_SELF).
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit AetherOrbits.ProcessCpu;

interface

/// <summary>
/// Stateful sampler: call Sample repeatedly; first call primes and returns 0.
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

/// <summary>Number of logical processors visible to this process.</summary>
function GetLogicalProcessorCount: Integer;

implementation

uses
  System.SysUtils,
  System.Diagnostics,
{$IF Defined(MSWINDOWS)}
  Winapi.Windows;
{$ELSEIF Defined(POSIX)}
  Posix.SysResource,
  Posix.SysTypes,
  Posix.Time;
{$ELSE}
  ;
{$ENDIF}

var
  GWallClock: TStopwatch;

function GetLogicalProcessorCount: Integer;
begin
{$IF Defined(MSWINDOWS)}
  Result := CPUCount;
  if Result < 1 then
    Result := 1;
{$ELSE}
  Result := CPUCount;
  if Result < 1 then
    Result := 1;
{$ENDIF}
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
  // FILETIME is 100-nanosecond ticks
  Result := (LKernel64 + LUser64) / 1.0E7;
end;
{$ELSEIF Defined(POSIX)}
var
  LUsage: rusage;
begin
  FillChar(LUsage, SizeOf(LUsage), 0);
  if getrusage(RUSAGE_SELF, LUsage) <> 0 then
  begin
    Exit(0);
  end;
  Result := LUsage.ru_utime.tv_sec + LUsage.ru_utime.tv_usec / 1.0E6
    + LUsage.ru_stime.tv_sec + LUsage.ru_stime.tv_usec / 1.0E6;
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