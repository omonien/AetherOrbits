/// <summary>
/// Helios.Scene
/// Simulation model for the Helios solar-system demo (bodies, camera, trails).
/// </summary>
///
/// <remarks>
/// <para>
/// <b>Role in the stack:</b> pure world state + fixed-timestep update. No FMX
/// forms, no Skia draw calls. The form calls <c>Update</c> from
/// <c>TGameLoop.OnUpdate</c>; <c>Helios.Scene.Renderer</c> projects and paints
/// on <c>OnDraw</c>. Hit-testing reuses the same projection as the renderer.
/// </para>
/// <para>
/// <b>World space:</b> soft 3D — X right, Y up, Z depth. Orbits are circles in
/// the XZ plane with a small inclination around X so rings read as ellipses
/// when projected. Scale is artistic (readable layout), not true AU/radii.
/// </para>
/// <para>
/// <b>Camera:</b> look-at target + distance, smoothly lerped toward goals.
/// Overview orbits the origin gently (idle yaw). Focus tracks a body while
/// orbits advance. Camera eases even while simulation is paused.
/// </para>
/// <para>
/// <b>Trails:</b> ring buffers of world samples per planet (not the Sun).
/// Sampled on a fixed interval in simulation time so high sim-speed still
/// fills trails without flooding every physics step.
/// </para>
/// <para>
/// <b>Sim speed / pause:</b> <c>Update</c> multiplies dt by <c>SimSpeed</c>
/// when not paused. Prefer changing speed here rather than GameLoop
/// FixedTimeStep (keeps the frame clock independent of “story” time).
/// </para>
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit Helios.Scene;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Math;

type
  /// <summary>Simple 3D vector used by the solar-system model.</summary>
  TVec3 = record
    X: Single;
    Y: Single;
    Z: Single;
    class function Create(const AX, AY, AZ: Single): TVec3; static;
    class function Zero: TVec3; static;
    function Add(const AOther: TVec3): TVec3;
    function Sub(const AOther: TVec3): TVec3;
    function Scale(const AFactor: Single): TVec3;
    function Length: Single;
    function Normalize: TVec3;
    function Lerp(const AOther: TVec3; const AT: Single): TVec3;
  end;

  /// <summary>One body in the system (Sun or planet).</summary>
  TBody = record
    Name: string;
    /// <summary>One-line fact for the info panel.</summary>
    Fact: string;
    /// <summary>Orbital radius in scene units (0 for the Sun).</summary>
    OrbitRadius: Single;
    /// <summary>Angular speed in rad/s at 1× simulation speed.</summary>
    OrbitSpeed: Single;
    /// <summary>Orbit tilt around X (radians) for a soft 3D look.</summary>
    Inclination: Single;
    /// <summary>Current orbital angle (radians).</summary>
    Angle: Single;
    /// <summary>Display radius of the sphere (scene units).</summary>
    Size: Single;
    Color: TAlphaColor;
    /// <summary>World position (updated each tick).</summary>
    Position: TVec3;
    /// <summary>Mean distance label (e.g. "1.00 AU").</summary>
    DistanceLabel: string;
    /// <summary>Orbital period label (e.g. "365 d").</summary>
    PeriodLabel: string;
  end;

  /// <summary>Static spawn definition for InitializeBodies.</summary>
  TBodyDef = record
    Name: string;
    Fact: string;
    OrbitRadius: Single;
    OrbitSpeed: Single;
    Inclination: Single;
    Size: Single;
    Color: TAlphaColor;
    DistanceLabel: string;
    PeriodLabel: string;
    Phase: Single;
  end;

  /// <summary>
  /// Ring-buffer trail of world-space samples for one body.
  /// </summary>
  TOrbitTrail = record
    Points: TArray<TVec3>;
    Head: Integer;
    Count: Integer;
    Capacity: Integer;
    procedure Reset(const ACapacity: Integer);
    procedure Push(const APoint: TVec3);
    function GetPoint(const AIndex: Integer): TVec3;
  end;

  /// <summary>
  /// Soft-3D camera: look-at target + distance, smoothly lerped toward goals.
  /// </summary>
  THeliosCamera = record
    Target: TVec3;
    Distance: Single;
    Yaw: Single;
    Pitch: Single;
    TargetGoal: TVec3;
    DistanceGoal: Single;
    procedure ResetOverview;
    procedure SetFocus(const AWorldPoint: TVec3; const ABodySize: Single);
    procedure Update(const ADeltaTime: Double);
    function EyePosition: TVec3;
  end;

  /// <summary>
  /// Solar-system scene: bodies, trails, camera focus, pause, and sim speed.
  /// </summary>
  THeliosScene = class
  private
    FBodies: TArray<TBody>;
    FTrails: TArray<TOrbitTrail>;
    FTime: Double;
    FViewportWidth: Single;
    FViewportHeight: Single;
    FInitialized: Boolean;
    FPaused: Boolean;
    FSimSpeed: Single;
    FShowTrails: Boolean;
    FShowLabels: Boolean;
    FFocusedIndex: Integer;
    FCamera: THeliosCamera;
    FTrailSampleTimer: Double;
    procedure InitializeBodies;
    procedure UpdateBodyPositions;
    procedure SampleTrails(const ADeltaTime: Double);
    function GetBodyCount: Integer;
    function GetBody(const AIndex: Integer): TBody;
    function GetTrail(const AIndex: Integer): TOrbitTrail;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Records surface size (used by the form for layout; projection uses ADest).</summary>
    procedure SetViewport(const AWidth, AHeight: Single);
    /// <summary>First-time setup: bodies, trails, overview camera, default speed.</summary>
    procedure Initialize(const AWidth, AHeight: Single);
    /// <summary>
    /// Advances simulation (orbits, trails) and camera ease.
    /// Call from game-loop OnUpdate with the fixed timestep.
    /// </summary>
    procedure Update(const ADeltaTime: Double);

    /// <summary>Toggle pause (simulation clock freezes; camera still eases).</summary>
    procedure TogglePause;
    procedure SetPaused(const AValue: Boolean);
    procedure SetSimSpeed(const ASpeed: Single);
    procedure SetShowTrails(const AValue: Boolean);
    procedure SetShowLabels(const AValue: Boolean);

    /// <summary>Focus camera on body index, or -1 for system overview.</summary>
    procedure FocusBody(const AIndex: Integer);
    procedure FocusOverview;

    /// <summary>
    /// Hit-test a screen point against projected body discs.
    /// Returns body index or -1. Uses the same projection as the renderer.
    /// </summary>
    function HitTestBody(
      const AScreenX, AScreenY: Single;
      const ADest: TRectF): Integer;

    /// <summary>
    /// Projects a world point into ADest using the live camera.
    /// Depth is 0 (near) .. 1 (far); Visible is False when behind the camera.
    /// </summary>
    function ProjectPoint(
      const AWorld: TVec3;
      const ADest: TRectF;
      out AScreen: TPointF;
      out ADepth: Single): Boolean;

    /// <summary>Projected radius of a body disc for the given destination rect.</summary>
    function ProjectedBodyRadius(
      const AIndex: Integer;
      const ADest: TRectF): Single;

    property Initialized: Boolean read FInitialized;
    property Time: Double read FTime;
    property ViewportWidth: Single read FViewportWidth;
    property ViewportHeight: Single read FViewportHeight;
    property Paused: Boolean read FPaused;
    property SimSpeed: Single read FSimSpeed;
    property ShowTrails: Boolean read FShowTrails;
    property ShowLabels: Boolean read FShowLabels;
    /// <summary>-1 = overview; 0..BodyCount-1 = focused body.</summary>
    property FocusedIndex: Integer read FFocusedIndex;
    property BodyCount: Integer read GetBodyCount;
    property Bodies[const AIndex: Integer]: TBody read GetBody;
    property Trails[const AIndex: Integer]: TOrbitTrail read GetTrail;
    property Camera: THeliosCamera read FCamera;
  end;

implementation

const
  cTrailCapacity = 96;
  cTrailSampleInterval = 0.05;
  cCameraLerpRate = 4.0;
  cDefaultSimSpeed = 1.0;
  cOverviewDistance = 920.0;
  cMinFocusDistance = 80.0;
  cFocusDistanceScale = 8.5;
  cPerspectiveFocal = 520.0;
  cHitSlop = 8.0;

  // Artistic scale (not real AU/radii) — readable layout, dark-space aesthetic.
  cBodyDefs: array[0..8] of TBodyDef = (
    (Name: 'Sun'; Fact: 'G-type star · fusion core';
     OrbitRadius: 0; OrbitSpeed: 0; Inclination: 0; Size: 42;
     Color: $FFFFC14A; DistanceLabel: '—'; PeriodLabel: '—'; Phase: 0),
    (Name: 'Mercury'; Fact: 'Rocky · extreme day/night swing';
     OrbitRadius: 70; OrbitSpeed: 1.60; Inclination: 0.12; Size: 6;
     Color: $FFB0B0B8; DistanceLabel: '0.39 AU'; PeriodLabel: '88 d'; Phase: 0.4),
    (Name: 'Venus'; Fact: 'Thick CO₂ atmosphere · hottest';
     OrbitRadius: 100; OrbitSpeed: 1.18; Inclination: -0.06; Size: 9;
     Color: $FFE8C57A; DistanceLabel: '0.72 AU'; PeriodLabel: '225 d'; Phase: 1.1),
    (Name: 'Earth'; Fact: 'Liquid water · nitrogen-oxygen air';
     OrbitRadius: 140; OrbitSpeed: 1.00; Inclination: 0.04; Size: 10;
     Color: $FF4EA0FF; DistanceLabel: '1.00 AU'; PeriodLabel: '365 d'; Phase: 2.0),
    (Name: 'Mars'; Fact: 'Iron-rich dust · thin air';
     OrbitRadius: 185; OrbitSpeed: 0.80; Inclination: 0.09; Size: 8;
     Color: $FFFF6B4A; DistanceLabel: '1.52 AU'; PeriodLabel: '687 d'; Phase: 2.7),
    (Name: 'Jupiter'; Fact: 'Gas giant · Great Red Spot';
     OrbitRadius: 280; OrbitSpeed: 0.43; Inclination: -0.03; Size: 22;
     Color: $FFE0A36A; DistanceLabel: '5.20 AU'; PeriodLabel: '12 y'; Phase: 0.2),
    (Name: 'Saturn'; Fact: 'Gas giant · prominent rings';
     OrbitRadius: 360; OrbitSpeed: 0.32; Inclination: 0.07; Size: 18;
     Color: $FFE8D5A0; DistanceLabel: '9.58 AU'; PeriodLabel: '29 y'; Phase: 3.5),
    (Name: 'Uranus'; Fact: 'Ice giant · extreme axial tilt';
     OrbitRadius: 430; OrbitSpeed: 0.22; Inclination: -0.10; Size: 14;
     Color: $FF7EC8E3; DistanceLabel: '19.2 AU'; PeriodLabel: '84 y'; Phase: 4.2),
    (Name: 'Neptune'; Fact: 'Ice giant · supersonic winds';
     OrbitRadius: 500; OrbitSpeed: 0.18; Inclination: 0.05; Size: 14;
     Color: $FF4169E1; DistanceLabel: '30.1 AU'; PeriodLabel: '165 y'; Phase: 5.0)
  );

{ TVec3 }

class function TVec3.Create(const AX, AY, AZ: Single): TVec3;
begin
  Result.X := AX;
  Result.Y := AY;
  Result.Z := AZ;
end;

class function TVec3.Zero: TVec3;
begin
  Result := TVec3.Create(0, 0, 0);
end;

function TVec3.Add(const AOther: TVec3): TVec3;
begin
  Result := TVec3.Create(X + AOther.X, Y + AOther.Y, Z + AOther.Z);
end;

function TVec3.Sub(const AOther: TVec3): TVec3;
begin
  Result := TVec3.Create(X - AOther.X, Y - AOther.Y, Z - AOther.Z);
end;

function TVec3.Scale(const AFactor: Single): TVec3;
begin
  Result := TVec3.Create(X * AFactor, Y * AFactor, Z * AFactor);
end;

function TVec3.Length: Single;
begin
  Result := Sqrt(X * X + Y * Y + Z * Z);
end;

function TVec3.Normalize: TVec3;
var
  L: Single;
begin
  L := Length;
  if L < 1E-6 then
    Result := TVec3.Zero
  else
    Result := Scale(1 / L);
end;

function TVec3.Lerp(const AOther: TVec3; const AT: Single): TVec3;
begin
  Result := TVec3.Create(
    X + (AOther.X - X) * AT,
    Y + (AOther.Y - Y) * AT,
    Z + (AOther.Z - Z) * AT);
end;

{ TOrbitTrail }

procedure TOrbitTrail.Reset(const ACapacity: Integer);
begin
  Capacity := Max(4, ACapacity);
  SetLength(Points, Capacity);
  Head := 0;
  Count := 0;
end;

procedure TOrbitTrail.Push(const APoint: TVec3);
begin
  if Capacity <= 0 then
  begin
    Exit;
  end;
  Points[Head] := APoint;
  Head := (Head + 1) mod Capacity;
  if Count < Capacity then
  begin
    Inc(Count);
  end;
end;

function TOrbitTrail.GetPoint(const AIndex: Integer): TVec3;
var
  LStart: Integer;
begin
  // AIndex 0 = oldest, Count-1 = newest
  if (AIndex < 0) or (AIndex >= Count) then
  begin
    Result := TVec3.Zero;
    Exit;
  end;
  LStart := (Head - Count + Capacity) mod Capacity;
  Result := Points[(LStart + AIndex) mod Capacity];
end;

{ THeliosCamera }

procedure THeliosCamera.ResetOverview;
begin
  Target := TVec3.Zero;
  TargetGoal := TVec3.Zero;
  Distance := cOverviewDistance;
  DistanceGoal := cOverviewDistance;
  Yaw := 0.55;
  Pitch := 0.42;
end;

procedure THeliosCamera.SetFocus(const AWorldPoint: TVec3; const ABodySize: Single);
begin
  TargetGoal := AWorldPoint;
  DistanceGoal := Max(cMinFocusDistance, ABodySize * cFocusDistanceScale + 40);
end;

procedure THeliosCamera.Update(const ADeltaTime: Double);
var
  LT: Single;
begin
  LT := 1 - Exp(-cCameraLerpRate * ADeltaTime);
  Target := Target.Lerp(TargetGoal, LT);
  Distance := Distance + (DistanceGoal - Distance) * LT;
  // Gentle idle yaw so overview never feels frozen.
  Yaw := Yaw + 0.04 * ADeltaTime;
end;

function THeliosCamera.EyePosition: TVec3;
var
  LCosP: Single;
begin
  LCosP := Cos(Pitch);
  Result := Target.Add(TVec3.Create(
    Sin(Yaw) * LCosP * Distance,
    Sin(Pitch) * Distance,
    Cos(Yaw) * LCosP * Distance));
end;

{ THeliosScene }

constructor THeliosScene.Create;
begin
  inherited Create;
  FInitialized := False;
  FPaused := False;
  FSimSpeed := cDefaultSimSpeed;
  FShowTrails := True;
  FShowLabels := True;
  FFocusedIndex := -1;
  FTime := 0;
  FTrailSampleTimer := 0;
  FCamera.ResetOverview;
end;

destructor THeliosScene.Destroy;
begin
  FBodies := nil;
  FTrails := nil;
  inherited;
end;

function THeliosScene.GetBodyCount: Integer;
begin
  Result := Length(FBodies);
end;

function THeliosScene.GetBody(const AIndex: Integer): TBody;
begin
  Result := FBodies[AIndex];
end;

function THeliosScene.GetTrail(const AIndex: Integer): TOrbitTrail;
begin
  Result := FTrails[AIndex];
end;

procedure THeliosScene.SetViewport(const AWidth, AHeight: Single);
begin
  FViewportWidth := AWidth;
  FViewportHeight := AHeight;
end;

procedure THeliosScene.InitializeBodies;
var
  i: Integer;
begin
  SetLength(FBodies, Length(cBodyDefs));
  SetLength(FTrails, Length(cBodyDefs));
  for i := 0 to High(cBodyDefs) do
  begin
    FBodies[i].Name := cBodyDefs[i].Name;
    FBodies[i].Fact := cBodyDefs[i].Fact;
    FBodies[i].OrbitRadius := cBodyDefs[i].OrbitRadius;
    FBodies[i].OrbitSpeed := cBodyDefs[i].OrbitSpeed;
    FBodies[i].Inclination := cBodyDefs[i].Inclination;
    FBodies[i].Size := cBodyDefs[i].Size;
    FBodies[i].Color := cBodyDefs[i].Color;
    FBodies[i].DistanceLabel := cBodyDefs[i].DistanceLabel;
    FBodies[i].PeriodLabel := cBodyDefs[i].PeriodLabel;
    FBodies[i].Angle := cBodyDefs[i].Phase;
    FTrails[i].Reset(cTrailCapacity);
  end;
  UpdateBodyPositions;
end;

procedure THeliosScene.UpdateBodyPositions;
// Recompute world positions from Angle / OrbitRadius / Inclination.
// Sun (OrbitRadius = 0) stays at the origin.
var
  i: Integer;
  LCosA, LSinA, LCosI, LSinI: Single;
  LX, LY, LZ: Single;
begin
  for i := 0 to High(FBodies) do
  begin
    if FBodies[i].OrbitRadius <= 0 then
    begin
      FBodies[i].Position := TVec3.Zero;
      Continue;
    end;
    LCosA := Cos(FBodies[i].Angle);
    LSinA := Sin(FBodies[i].Angle);
    LCosI := Cos(FBodies[i].Inclination);
    LSinI := Sin(FBodies[i].Inclination);
    // Circle in XZ, then tilt around X → LY = Z * sin(i), Z' = Z * cos(i).
    LX := LCosA * FBodies[i].OrbitRadius;
    LZ := LSinA * FBodies[i].OrbitRadius;
    LY := LZ * LSinI;
    LZ := LZ * LCosI;
    FBodies[i].Position := TVec3.Create(LX, LY, LZ);
  end;
end;

procedure THeliosScene.Initialize(const AWidth, AHeight: Single);
begin
  SetViewport(AWidth, AHeight);
  FTime := 0;
  FPaused := False;
  FSimSpeed := cDefaultSimSpeed;
  FShowTrails := True;
  FShowLabels := True;
  FFocusedIndex := -1;
  FTrailSampleTimer := 0;
  FCamera.ResetOverview;
  InitializeBodies;
  FInitialized := True;
end;

procedure THeliosScene.SampleTrails(const ADeltaTime: Double);
var
  i: Integer;
begin
  FTrailSampleTimer := FTrailSampleTimer + ADeltaTime;
  if FTrailSampleTimer < cTrailSampleInterval then
  begin
    Exit;
  end;
  FTrailSampleTimer := 0;
  for i := 1 to High(FBodies) do
  begin
    // Skip the Sun — no orbit trail.
    FTrails[i].Push(FBodies[i].Position);
  end;
end;

procedure THeliosScene.Update(const ADeltaTime: Double);
// Fixed-timestep entry from TGameLoop.OnUpdate.
// Camera always eases; orbit integration respects Pause and SimSpeed.
var
  LSimDt: Double;
  i: Integer;
begin
  if not FInitialized then
  begin
    Exit;
  end;

  // Keep focus goal locked to the body (or overview goal from FocusOverview).
  // Done before the pause early-out so the camera can still settle while frozen.
  if (FFocusedIndex >= 0) and (FFocusedIndex < Length(FBodies)) then
  begin
    FCamera.SetFocus(FBodies[FFocusedIndex].Position, FBodies[FFocusedIndex].Size);
  end;
  FCamera.Update(ADeltaTime);

  if FPaused then
  begin
    Exit;
  end;

  // Story time ≠ wall/frame clock: scale only the simulation delta.
  LSimDt := ADeltaTime * FSimSpeed;
  FTime := FTime + LSimDt;

  for i := 0 to High(FBodies) do
  begin
    if FBodies[i].OrbitSpeed <> 0 then
    begin
      FBodies[i].Angle := FBodies[i].Angle + FBodies[i].OrbitSpeed * LSimDt;
    end;
  end;
  UpdateBodyPositions;
  SampleTrails(LSimDt);
end;

procedure THeliosScene.TogglePause;
begin
  FPaused := not FPaused;
end;

procedure THeliosScene.SetPaused(const AValue: Boolean);
begin
  FPaused := AValue;
end;

procedure THeliosScene.SetSimSpeed(const ASpeed: Single);
begin
  FSimSpeed := Max(0.05, ASpeed);
end;

procedure THeliosScene.SetShowTrails(const AValue: Boolean);
begin
  FShowTrails := AValue;
end;

procedure THeliosScene.SetShowLabels(const AValue: Boolean);
begin
  FShowLabels := AValue;
end;

procedure THeliosScene.FocusBody(const AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= Length(FBodies)) then
  begin
    FocusOverview;
    Exit;
  end;
  FFocusedIndex := AIndex;
  FCamera.SetFocus(FBodies[AIndex].Position, FBodies[AIndex].Size);
end;

procedure THeliosScene.FocusOverview;
begin
  FFocusedIndex := -1;
  FCamera.TargetGoal := TVec3.Zero;
  FCamera.DistanceGoal := cOverviewDistance;
end;

function THeliosScene.ProjectPoint(
  const AWorld: TVec3;
  const ADest: TRectF;
  out AScreen: TPointF;
  out ADepth: Single): Boolean;
// Simple pinhole projection shared by the renderer and hit-testing.
// Camera basis: forward (to target), right (forward × world-up), up (right × forward).
// Returns False when the point is behind / too close to the near plane (LCamZ ≤ 1).
var
  LEye: TVec3;
  LForward: TVec3;
  LWorldUp: TVec3;
  LRight: TVec3;
  LUp: TVec3;
  LRel: TVec3;
  LCamX, LCamY, LCamZ: Single;
  LScale: Single;
begin
  LEye := FCamera.EyePosition;
  LForward := FCamera.Target.Sub(LEye).Normalize;
  LWorldUp := TVec3.Create(0, 1, 0);
  LRight := TVec3.Create(
    LForward.Y * LWorldUp.Z - LForward.Z * LWorldUp.Y,
    LForward.Z * LWorldUp.X - LForward.X * LWorldUp.Z,
    LForward.X * LWorldUp.Y - LForward.Y * LWorldUp.X).Normalize;
  // Re-orthogonalize up so the basis stays right-handed after cross products.
  LUp := TVec3.Create(
    LRight.Y * LForward.Z - LRight.Z * LForward.Y,
    LRight.Z * LForward.X - LRight.X * LForward.Z,
    LRight.X * LForward.Y - LRight.Y * LForward.X).Normalize;

  LRel := AWorld.Sub(LEye);
  LCamX := LRel.X * LRight.X + LRel.Y * LRight.Y + LRel.Z * LRight.Z;
  LCamY := LRel.X * LUp.X + LRel.Y * LUp.Y + LRel.Z * LUp.Z;
  LCamZ := LRel.X * LForward.X + LRel.Y * LForward.Y + LRel.Z * LForward.Z;

  if LCamZ <= 1.0 then
  begin
    Result := False;
    AScreen := TPointF.Zero;
    ADepth := 1;
    Exit;
  end;

  // Uniform scale (no aspect stretch) — keeps planets circular on any window shape.
  LScale := cPerspectiveFocal / LCamZ;
  AScreen := TPointF.Create(
    ADest.CenterPoint.X + LCamX * LScale,
    ADest.CenterPoint.Y - LCamY * LScale);
  ADepth := LCamZ / (FCamera.Distance + 400);
  ADepth := EnsureRange(ADepth, 0, 1);
  Result := True;
end;

function THeliosScene.ProjectedBodyRadius(
  const AIndex: Integer;
  const ADest: TRectF): Single;
var
  LScreen: TPointF;
  LDepth: Single;
  LEye: TVec3;
  LRel: TVec3;
  LCamZ: Single;
  LForward: TVec3;
begin
  if (AIndex < 0) or (AIndex >= Length(FBodies)) then
  begin
    Result := 0;
    Exit;
  end;
  if not ProjectPoint(FBodies[AIndex].Position, ADest, LScreen, LDepth) then
  begin
    Result := 0;
    Exit;
  end;
  LEye := FCamera.EyePosition;
  LForward := FCamera.Target.Sub(LEye).Normalize;
  LRel := FBodies[AIndex].Position.Sub(LEye);
  LCamZ := LRel.X * LForward.X + LRel.Y * LForward.Y + LRel.Z * LForward.Z;
  if LCamZ <= 1 then
  begin
    Result := 0;
    Exit;
  end;
  Result := FBodies[AIndex].Size * (cPerspectiveFocal / LCamZ);
end;

function THeliosScene.HitTestBody(
  const AScreenX, AScreenY: Single;
  const ADest: TRectF): Integer;
var
  i: Integer;
  LScreen: TPointF;
  LDepth: Single;
  LRadius: Single;
  LDist: Single;
  LBestDist: Single;
  LClick: TPointF;
begin
  Result := -1;
  if not FInitialized then
  begin
    Exit;
  end;

  LClick := TPointF.Create(AScreenX, AScreenY);
  LBestDist := MaxSingle;

  // Prefer nearer bodies when discs overlap.
  for i := 0 to High(FBodies) do
  begin
    if not ProjectPoint(FBodies[i].Position, ADest, LScreen, LDepth) then
    begin
      Continue;
    end;
    LRadius := ProjectedBodyRadius(i, ADest) + cHitSlop;
    LDist := LClick.Distance(LScreen);
    if (LDist <= LRadius) and (LDist < LBestDist) then
    begin
      // Bias by depth so closer body wins ties.
      LBestDist := LDist + LDepth * 0.01;
      Result := i;
    end;
  end;
end;

end.
