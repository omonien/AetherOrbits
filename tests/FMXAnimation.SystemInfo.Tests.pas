/// <summary>
/// FMXAnimation.SystemInfo.Tests
/// </summary>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit FMXAnimation.SystemInfo.Tests;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  FMXAnimation.SystemInfo;

type
  [TestFixture]
  TSystemInfoTests = class
  public
    [Test]
    procedure HostPlatformLabel_IsNonEmpty;
    [Test]
    procedure HostPlatformLabel_OmitsBuildZero;
    [Test]
    procedure PreferredFramesPerSecond_RoundTrip;
    [Test]
    procedure RenderBackendLabel_IsNonEmpty;
    [Test]
    procedure LogicalProcessorCount_AtLeastOne;
    [Test]
    procedure CpuSampler_FirstSamplePrimes;
  end;

implementation

procedure TSystemInfoTests.HostPlatformLabel_IsNonEmpty;
begin
  Assert.IsTrue(GetHostPlatformLabel <> '', 'Platform label empty');
end;

procedure TSystemInfoTests.HostPlatformLabel_OmitsBuildZero;
begin
  // TOSVersion.Build is often 0 on iOS/macOS; never show a useless "(build 0)".
  Assert.IsFalse(
    GetHostPlatformLabel.Contains('(build 0)'),
    'Platform label must omit build when Build is 0');
end;

procedure TSystemInfoTests.PreferredFramesPerSecond_RoundTrip;
var
  LSaved: Integer;
begin
  LSaved := GetPreferredFramesPerSecond;
  try
    SetPreferredFramesPerSecond(30);
    Assert.AreEqual(30, GetPreferredFramesPerSecond);
    SetPreferredFramesPerSecond(120);
    Assert.AreEqual(120, GetPreferredFramesPerSecond);
    SetPreferredFramesPerSecond(0);
    Assert.AreEqual(60, GetPreferredFramesPerSecond, 'Invalid values fall back to 60');
  finally
    SetPreferredFramesPerSecond(LSaved);
  end;
end;

procedure TSystemInfoTests.RenderBackendLabel_IsNonEmpty;
begin
  Assert.IsTrue(GetActiveRenderBackendLabel <> '', 'Backend label empty');
end;

procedure TSystemInfoTests.LogicalProcessorCount_AtLeastOne;
begin
  Assert.IsTrue(GetLogicalProcessorCount >= 1);
end;

procedure TSystemInfoTests.CpuSampler_FirstSamplePrimes;
var
  LSampler: TProcessCpuSampler;
begin
  LSampler.Reset;
  Assert.AreEqual(0.0, LSampler.Sample, 1E-9, 'First sample primes and returns 0');
end;

end.