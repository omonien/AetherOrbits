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
  // System
  System.SysUtils,
  System.Classes,
  // FMX
  FMX.Forms,
  // Test
  DUnitX.TestFramework,
  // Own
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
    FForm: TForm;
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
    [Test]
    procedure Create_WithFmxOwner_SetsParent;
    [Test]
    procedure StartLoop_WithoutRoot_Raises;
  end;

implementation

{ TGameLoopHarness }

procedure TGameLoopHarness.Tick;
begin
  ProcessAnimation;
end;

{ TGameLoopTests }

procedure TGameLoopTests.SetUp;
begin
  // Form provides Root so StartLoop can subscribe to Display Link
  FForm := TForm.CreateNew(nil);
  FLoop := TGameLoopHarness.Create(FForm);
  FUpdateCount := 0;
  FRenderCount := 0;
  FLastDelta := 0;
  FLoop.OnUpdate := HandleUpdate;
  FLoop.OnRender := HandleRender;
end;

procedure TGameLoopTests.TearDown;
begin
  FreeAndNil(FLoop);
  FreeAndNil(FForm);
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
  FLoop.MaxFrameTime := 0.05;
  FLoop.StartLoop;
  try
    Sleep(200);
    FLoop.Tick;

    Assert.IsTrue(FUpdateCount <= 3,
      Format('Updates %d should be clamped by MaxFrameTime', [FUpdateCount]));
    Assert.IsTrue(FUpdateCount >= 1, 'Still expect at least one update after pause');
  finally
    FLoop.StopLoop;
  end;
end;

procedure TGameLoopTests.ProcessAnimation_InvokesRenderOncePerTick;
begin
  FLoop.StartLoop;
  try
    FRenderCount := 0;
    FUpdateCount := 0;

    FLoop.Tick;
    FLoop.Tick;

    Assert.AreEqual(2, FRenderCount, 'OnRender once per Tick call');
  finally
    FLoop.StopLoop;
  end;
end;

procedure TGameLoopTests.Create_WithFmxOwner_SetsParent;
var
  LForm: TForm;
  LLoop: TGameLoop;
begin
  LForm := TForm.CreateNew(nil);
  try
    LLoop := TGameLoop.Create(LForm);
    try
      Assert.AreSame(LForm, LLoop.Parent,
        'GameLoop must parent to FMX owner for Root/Display Link');
    finally
      LLoop.Free;
    end;
  finally
    LForm.Free;
  end;
end;

procedure TGameLoopTests.StartLoop_WithoutRoot_Raises;
var
  LLoop: TGameLoop;
begin
  LLoop := TGameLoop.Create(nil);
  try
    Assert.WillRaise(
      procedure
      begin
        LLoop.StartLoop;
      end,
      EInvalidOpException);
  finally
    LLoop.Free;
  end;
end;

end.