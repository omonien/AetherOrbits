/// <summary>
/// AetherOrbits.Scene.Tests
/// DUnitX tests for the pure simulation scene.
/// </summary>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit AetherOrbits.Scene.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Types,
  AetherOrbits.Scene;

type
  [TestFixture]
  TAetherSceneTests = class
  private
    FScene: TAetherScene;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Initialize_CreatesOrbsAndParticles;
    [Test]
    procedure Update_AdvancesTime;
    [Test]
    procedure Update_BeforeInitialize_IsNoOp;
    [Test]
    procedure SetMousePosition_IsStored;
    [Test]
    procedure PointerDown_SpawnsBurstParticles;
    [Test]
    procedure SetViewport_UpdatesCenter;
    [Test]
    procedure GetOrbWorldPosition_MatchesEllipseModel;
    [Test]
    procedure ParticleCount_NeverExceedsMaxCap;
  end;

implementation

const
  cMaxParticlesExpected = 500;
  cOrbEllipseYScale = 0.72;

{ TAetherSceneTests }

procedure TAetherSceneTests.SetUp;
begin
  FScene := TAetherScene.Create;
end;

procedure TAetherSceneTests.TearDown;
begin
  FreeAndNil(FScene);
end;

procedure TAetherSceneTests.Initialize_CreatesOrbsAndParticles;
begin
  FScene.Initialize(1280, 720);

  Assert.IsTrue(FScene.Initialized);
  Assert.AreEqual(5, FScene.OrbCount, 'Orb count from data table');
  Assert.IsTrue(FScene.ParticleCount > 0, 'Expected seed particles');
  Assert.AreEqual(1280.0, FScene.ViewportWidth, 0.01);
  Assert.AreEqual(720.0, FScene.ViewportHeight, 0.01);
end;

procedure TAetherSceneTests.Update_AdvancesTime;
const
  cStep = 1 / 60;
begin
  FScene.Initialize(800, 600);
  var LBefore := FScene.Time;

  FScene.Update(cStep);
  FScene.Update(cStep);

  Assert.AreEqual(LBefore + 2 * cStep, FScene.Time, 1E-12);
end;

procedure TAetherSceneTests.Update_BeforeInitialize_IsNoOp;
begin
  FScene.Update(1 / 60);
  Assert.IsFalse(FScene.Initialized);
  Assert.AreEqual(0.0, FScene.Time, 1E-12);
  Assert.AreEqual(0, FScene.OrbCount);
end;

procedure TAetherSceneTests.SetMousePosition_IsStored;
begin
  FScene.Initialize(100, 100);
  FScene.SetMousePosition(TPointF.Create(42, 24));

  Assert.AreEqual(42.0, FScene.Mouse.X, 0.01);
  Assert.AreEqual(24.0, FScene.Mouse.Y, 0.01);
end;

procedure TAetherSceneTests.PointerDown_SpawnsBurstParticles;
var
  LBefore: Integer;
begin
  FScene.Initialize(800, 600);
  LBefore := FScene.ParticleCount;
  FScene.PointerDown(TPointF.Create(100, 100));

  Assert.AreEqual(100.0, FScene.Mouse.X, 0.01);
  Assert.AreEqual(100.0, FScene.Mouse.Y, 0.01);
  Assert.IsTrue(FScene.ParticleCount > LBefore, 'Click/tap should spawn a particle burst');
end;

procedure TAetherSceneTests.SetViewport_UpdatesCenter;
begin
  FScene.Initialize(100, 100);
  FScene.SetViewport(200, 400);

  Assert.AreEqual(100.0, FScene.Center.X, 0.01);
  Assert.AreEqual(200.0, FScene.Center.Y, 0.01);
end;

procedure TAetherSceneTests.GetOrbWorldPosition_MatchesEllipseModel;
var
  LOrb: TOrb;
  LPos: TPointF;
  LExpected: TPointF;
begin
  FScene.Initialize(400, 300);
  LOrb := FScene.Orbs[0];
  LPos := FScene.GetOrbWorldPosition(0);
  LExpected := FScene.Center + TPointF.Create(
    Cos(LOrb.Angle) * LOrb.Radius,
    Sin(LOrb.Angle) * LOrb.Radius * cOrbEllipseYScale);

  Assert.AreEqual(LExpected.X, LPos.X, 1E-4);
  Assert.AreEqual(LExpected.Y, LPos.Y, 1E-4);
end;

procedure TAetherSceneTests.ParticleCount_NeverExceedsMaxCap;
const
  cStep = 1 / 60;
begin
  FScene.Initialize(800, 600);

  // Drive many updates with high spawn pressure via time
  for var i := 0 to 5000 do
  begin
    FScene.Update(cStep);
  end;

  Assert.IsTrue(FScene.ParticleCount <= cMaxParticlesExpected,
    Format('ParticleCount %d exceeded cap %d', [FScene.ParticleCount, cMaxParticlesExpected]));
end;

end.