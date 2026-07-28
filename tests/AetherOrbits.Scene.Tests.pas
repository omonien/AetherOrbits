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
    procedure SetViewport_UpdatesCenter;
  end;

implementation

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

  Assert.AreEqual(5, FScene.OrbCount, 'Orb count');
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

  Assert.AreEqual(LBefore + 2 * cStep, FScene.Time, 1E-12, 'Time should advance by 2 steps');
end;

procedure TAetherSceneTests.Update_BeforeInitialize_IsNoOp;
begin
  FScene.Update(1 / 60);
  Assert.AreEqual(0.0, FScene.Time, 1E-12, 'Time stays zero until Initialize');
  Assert.AreEqual(0, FScene.OrbCount, 'No orbs before Initialize');
end;

procedure TAetherSceneTests.SetMousePosition_IsStored;
begin
  FScene.Initialize(100, 100);
  FScene.SetMousePosition(TPointF.Create(42, 24));

  Assert.AreEqual(42.0, FScene.Mouse.X, 0.01);
  Assert.AreEqual(24.0, FScene.Mouse.Y, 0.01);
end;

procedure TAetherSceneTests.SetViewport_UpdatesCenter;
begin
  FScene.Initialize(100, 100);
  FScene.SetViewport(200, 400);

  Assert.AreEqual(100.0, FScene.Center.X, 0.01);
  Assert.AreEqual(200.0, FScene.Center.Y, 0.01);
end;

end.