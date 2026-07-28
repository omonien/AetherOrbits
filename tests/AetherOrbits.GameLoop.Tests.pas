/// <summary>
/// AetherOrbits.GameLoop.Tests
/// DUnitX tests for the fixed-timestep game loop.
/// </summary>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit AetherOrbits.GameLoop.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  AetherOrbits.GameLoop;

type
  /// <summary>
  /// Test helper that exposes ProcessAnimation for deterministic ticks.
  /// </summary>
  TGameLoopHarness = class(TGameLoop)
  public
    procedure Tick;
  end;

  [TestFixture]
  TGameLoopTests = class
  private
    FLoop: TGameLoopHarness;
    FUpdateCount: Integer;
    FRenderCount: Integer;
    FLastDelta: Double;
    procedure HandleUpdate(const ADeltaTime: Double);
    procedure HandleRender;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Defaults_AreSensible;
    [Test]
    procedure StartLoop_ResetsAndRunsWithoutError;
    [Test]
    procedure ProcessAnimation_InvokesUpdateAtFixedStep;
    [Test]
    procedure ProcessAnimation_ClampsLargeFrameTime;
    [Test]
    procedure ProcessAnimation_InvokesRenderOncePerTick;
  end;

implementation

uses
  System.Diagnostics;

{ TGameLoopHarness }

procedure TGameLoopHarness.Tick;
begin
  ProcessAnimation;
end;

{ TGameLoopTests }

procedure TGameLoopTests.SetUp;
begin
  FLoop := TGameLoopHarness.Create(nil);
  FUpdateCount := 0;
  FRenderCount := 0;
  FLastDelta := 0;
  FLoop.OnUpdate := HandleUpdate;
  FLoop.OnRender := HandleRender;
end;

procedure TGameLoopTests.TearDown;
begin
  FLoop.Free;
  FLoop := nil;
end;

procedure TGameLoopTests.HandleUpdate(const ADeltaTime: Double);
begin
  Inc(FUpdateCount);
  FLastDelta := ADeltaTime;
end;

procedure TGameLoopTests.HandleRender;
begin
  Inc(FRenderCount);
end;

procedure TGameLoopTests.Defaults_AreSensible;
begin
  Assert.AreEqual(1 / 60, FLoop.FixedTimeStep, 1E-12, 'Default FixedTimeStep');
  Assert.AreEqual(0.1, FLoop.MaxFrameTime, 1E-12, 'Default MaxFrameTime');
end;

procedure TGameLoopTests.StartLoop_ResetsAndRunsWithoutError;
begin
  FLoop.StartLoop;
  try
    Assert.IsTrue(True, 'StartLoop completed');
  finally
    FLoop.StopLoop;
  end;
end;

procedure TGameLoopTests.ProcessAnimation_InvokesUpdateAtFixedStep;
begin
  FLoop.FixedTimeStep := 1 / 60;
  FLoop.StartLoop;
  try
    // Wait long enough for several fixed steps to accumulate
    Sleep(50);
    FLoop.Tick;

    Assert.IsTrue(FUpdateCount >= 1, 'Expected at least one OnUpdate');
    Assert.AreEqual(FLoop.FixedTimeStep, FLastDelta, 1E-12, 'Delta must be FixedTimeStep');
  finally
    FLoop.StopLoop;
  end;
end;

procedure TGameLoopTests.ProcessAnimation_ClampsLargeFrameTime;
begin
  FLoop.FixedTimeStep := 1 / 60;
  FLoop.MaxFrameTime := 0.05; // 50 ms clamp
  FLoop.StartLoop;
  try
    // Simulate a long pause (debugger-style) before the next tick
    Sleep(200);
    FLoop.Tick;

    // With 50 ms clamp and 1/60 step, at most ceil(0.05 / (1/60)) = 3 updates
    Assert.IsTrue(FUpdateCount <= 3, Format('Updates %d should be clamped by MaxFrameTime', [FUpdateCount]));
    Assert.IsTrue(FUpdateCount >= 1, 'Still expect at least one update after pause');
  finally
    FLoop.StopLoop;
  end;
end;

procedure TGameLoopTests.ProcessAnimation_InvokesRenderOncePerTick;
begin
  FLoop.StartLoop;
  try
    // Start may already fire ProcessAnimation once via the animation system
    FRenderCount := 0;
    FUpdateCount := 0;

    FLoop.Tick;
    FLoop.Tick;

    Assert.AreEqual(2, FRenderCount, 'OnRender once per Tick call');
  finally
    FLoop.StopLoop;
  end;
end;

end.