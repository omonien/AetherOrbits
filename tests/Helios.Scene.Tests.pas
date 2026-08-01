/// <summary>
/// Helios.Scene.Tests
/// DUnitX tests for the Helios solar-system simulation model.
/// </summary>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit Helios.Scene.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Types,
  Helios.Scene;

type
  [TestFixture]
  THeliosSceneTests = class
  private
    FScene: THeliosScene;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Initialize_CreatesNineBodies;
    [Test]
    procedure Update_AdvancesTimeWhenRunning;
    [Test]
    procedure Update_Paused_DoesNotAdvanceTime;
    [Test]
    procedure SetSimSpeed_ScalesTimeAdvance;
    [Test]
    procedure FocusBody_SetsFocusedIndex;
    [Test]
    procedure FocusOverview_ClearsFocus;
    [Test]
    procedure ProjectPoint_SunIsVisibleInOverview;
    [Test]
    procedure HitTestBody_CenterHitsSun;
    [Test]
    procedure Trails_GrowAfterUpdates;
  end;

implementation

{ THeliosSceneTests }

procedure THeliosSceneTests.SetUp;
begin
  FScene := THeliosScene.Create;
end;

procedure THeliosSceneTests.TearDown;
begin
  FreeAndNil(FScene);
end;

procedure THeliosSceneTests.Initialize_CreatesNineBodies;
begin
  FScene.Initialize(1280, 720);

  Assert.IsTrue(FScene.Initialized);
  Assert.AreEqual(9, FScene.BodyCount, 'Sun + 8 planets');
  Assert.AreEqual('Sun', FScene.Bodies[0].Name);
  Assert.AreEqual('Neptune', FScene.Bodies[8].Name);
  Assert.AreEqual(-1, FScene.FocusedIndex);
  Assert.IsTrue(FScene.ShowTrails);
  Assert.IsFalse(FScene.Paused);
end;

procedure THeliosSceneTests.Update_AdvancesTimeWhenRunning;
const
  cStep = 1 / 60;
begin
  FScene.Initialize(800, 600);
  var LBefore := FScene.Time;

  FScene.Update(cStep);
  FScene.Update(cStep);

  Assert.AreEqual(LBefore + 2 * cStep, FScene.Time, 1E-9);
end;

procedure THeliosSceneTests.Update_Paused_DoesNotAdvanceTime;
const
  cStep = 1 / 60;
begin
  FScene.Initialize(800, 600);
  FScene.SetPaused(True);
  var LBefore := FScene.Time;

  FScene.Update(cStep);
  FScene.Update(cStep);

  Assert.AreEqual(LBefore, FScene.Time, 1E-12);
  Assert.IsTrue(FScene.Paused);
end;

procedure THeliosSceneTests.SetSimSpeed_ScalesTimeAdvance;
const
  cStep = 1 / 60;
begin
  FScene.Initialize(800, 600);
  FScene.SetSimSpeed(5.0);

  FScene.Update(cStep);

  Assert.AreEqual(cStep * 5.0, FScene.Time, 1E-9);
  Assert.AreEqual(5.0, FScene.SimSpeed, 1E-6);
end;

procedure THeliosSceneTests.FocusBody_SetsFocusedIndex;
begin
  FScene.Initialize(800, 600);
  FScene.FocusBody(3); // Earth

  Assert.AreEqual(3, FScene.FocusedIndex);
  Assert.AreEqual('Earth', FScene.Bodies[3].Name);
end;

procedure THeliosSceneTests.FocusOverview_ClearsFocus;
begin
  FScene.Initialize(800, 600);
  FScene.FocusBody(1);
  FScene.FocusOverview;

  Assert.AreEqual(-1, FScene.FocusedIndex);
end;

procedure THeliosSceneTests.ProjectPoint_SunIsVisibleInOverview;
var
  LScreen: TPointF;
  LDepth: Single;
  LDest: TRectF;
begin
  FScene.Initialize(800, 600);
  LDest := TRectF.Create(0, 0, 800, 600);

  Assert.IsTrue(
    FScene.ProjectPoint(FScene.Bodies[0].Position, LDest, LScreen, LDepth),
    'Sun should project while camera looks at origin');
  Assert.IsTrue(LDest.Contains(LScreen), 'Sun should land inside the viewport');
end;

procedure THeliosSceneTests.HitTestBody_CenterHitsSun;
var
  LScreen: TPointF;
  LDepth: Single;
  LDest: TRectF;
  LHit: Integer;
begin
  FScene.Initialize(800, 600);
  LDest := TRectF.Create(0, 0, 800, 600);
  Assert.IsTrue(FScene.ProjectPoint(FScene.Bodies[0].Position, LDest, LScreen, LDepth));

  LHit := FScene.HitTestBody(LScreen.X, LScreen.Y, LDest);
  Assert.AreEqual(0, LHit, 'Click on projected Sun should hit index 0');
end;

procedure THeliosSceneTests.Trails_GrowAfterUpdates;
var
  i: Integer;
begin
  FScene.Initialize(800, 600);
  FScene.SetSimSpeed(20.0);

  for i := 1 to 120 do
  begin
    FScene.Update(1 / 60);
  end;

  Assert.IsTrue(FScene.Trails[3].Count > 0, 'Earth trail should accumulate samples');
  Assert.AreEqual(0, FScene.Trails[0].Count, 'Sun has no orbit trail');
end;

end.
