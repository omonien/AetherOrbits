/// <summary>
/// AetherOrbits.Scene
/// Simulation model for the Aether Orbits demo (orbs + particles).
/// </summary>
///
/// <remarks>
/// Contains only game state and fixed-timestep update logic. No UI, no
/// rendering. The form owns a TAetherScene and drives Update from TGameLoop;
/// AetherOrbits.Scene.Renderer draws the state via Skia.
///
/// Particles live in a dense prefix of the Particles array (indices
/// 0..ParticleCount-1). Renderers should iterate that range and treat the
/// array reference as read-only.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit AetherOrbits.Scene;

interface

uses
  // System
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Math;

type
  /// <summary>
  /// Single particle in the scene.
  /// </summary>
  TParticle = record
    Position: TPointF;
    Velocity: TPointF;
    Life: Single;
    MaxLife: Single;
    Size: Single;
    Hue: Single;
  end;

  /// <summary>
  /// Orbiting body around the scene center.
  /// </summary>
  TOrb = record
    Angle: Single;
    Radius: Single;
    Speed: Single;
    Size: Single;
    BaseSize: Single;
    Color: TAlphaColor;
    Phase: Single;
  end;

  /// <summary>
  /// Static orb spawn definition (data table for InitializeOrbs).
  /// </summary>
  TOrbDef = record
    Radius: Single;
    Speed: Single;
    BaseSize: Single;
    Color: TAlphaColor;
    Phase: Single;
  end;

  /// <summary>
  /// Demo scene: orbs, particles, and mouse interaction state.
  /// </summary>
  TAetherScene = class
  private
    FParticles: TArray<TParticle>;
    FParticleCount: Integer;
    FOrbs: TArray<TOrb>;
    FTime: Double;
    FMouse: TPointF;
    FCenter: TPointF;
    FViewportWidth: Single;
    FViewportHeight: Single;
    FInitialized: Boolean;

    procedure SpawnParticle(const ANear: TPointF; const AForce: Single);
    procedure InitializeOrbs;
    procedure SeedInitialParticles;
    procedure RemoveParticleAt(const AIndex: Integer);
    function GetOrbCount: Integer;
    function GetOrb(const AIndex: Integer): TOrb;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    /// Sets viewport size and re-centers. Does not reset entities.
    /// </summary>
    procedure SetViewport(const AWidth, AHeight: Single);

    /// <summary>
    /// First-time setup: viewport + orbs + seed particles.
    /// </summary>
    procedure Initialize(const AWidth, AHeight: Single);

    /// <summary>
    /// Updates mouse position used for particle repulsion.
    /// </summary>
    procedure SetMousePosition(const APosition: TPointF);

    /// <summary>
    /// Advances simulation by a fixed delta (call from game-loop OnUpdate).
    /// </summary>
    procedure Update(const ADeltaTime: Double);

    /// <summary>
    /// World-space position of orb AIndex (ellipse orbit model).
    /// </summary>
    function GetOrbWorldPosition(const AIndex: Integer): TPointF;

    property Initialized: Boolean read FInitialized;
    property Time: Double read FTime;
    property Center: TPointF read FCenter;
    property Mouse: TPointF read FMouse;
    property ViewportWidth: Single read FViewportWidth;
    property ViewportHeight: Single read FViewportHeight;
    /// <summary>Live particle count; only Particles[0..Count-1] are valid.</summary>
    property ParticleCount: Integer read FParticleCount;
    /// <summary>Backing store; treat as read-only; use ParticleCount, not Length.</summary>
    property Particles: TArray<TParticle> read FParticles;
    property OrbCount: Integer read GetOrbCount;
    property Orbs[const AIndex: Integer]: TOrb read GetOrb;
  end;

implementation

const
  /// <summary>Hard cap — spawn is skipped when full (keeps load bounded).</summary>
  cMaxParticles = 500;
  cInitialParticleCount = 120;
  cMouseInfluenceRadius = 180.0;
  cMouseRepulsionStrength = 28.0;
  cCenterPullStrength = 4.0;
  cVelocityDamping = 0.85;
  cOrbSpawnChance = 0.35;
  cOrbSpawnForce = 0.6;
  cSeedParticleForce = 0.3;
  cOrbPulseAmplitude = 0.12;
  cOrbPulseFrequency = 2.1;
  /// <summary>Y-scale for elliptical orbits (shared with renderer via GetOrbWorldPosition).</summary>
  cOrbEllipseYScale = 0.72;
  cParticleSpawnJitter = 40.0;
  cParticleMinLife = 1.8;
  cParticleLifeVariance = 2.5;
  cParticleMinSize = 1.2;
  cParticleSizeVariance = 2.8;
  cMinVectorLength = 1E-4;

  cOrbDefs: array[0..4] of TOrbDef = (
    (Radius: 140; Speed:  0.35; BaseSize: 28; Color: $FF00E5FF; Phase: 0.0),
    (Radius: 210; Speed: -0.22; BaseSize: 18; Color: $FFFF2E9F; Phase: 1.2),
    (Radius: 280; Speed:  0.15; BaseSize: 22; Color: $FFFFD166; Phase: 2.8),
    (Radius: 175; Speed: -0.41; BaseSize: 14; Color: $FF7B61FF; Phase: 4.1),
    (Radius: 320; Speed:  0.09; BaseSize: 16; Color: $FF00FFA3; Phase: 0.7)
  );

{ TAetherScene }

constructor TAetherScene.Create;
begin
  inherited Create;
  FParticleCount := 0;
  SetLength(FParticles, 0);
  FTime := 0;
  FInitialized := False;
  FViewportWidth := 0;
  FViewportHeight := 0;
  FMouse := TPointF.Zero;
  FCenter := TPointF.Zero;
end;

destructor TAetherScene.Destroy;
begin
  FParticles := nil;
  FOrbs := nil;
  inherited;
end;

function TAetherScene.GetOrbCount: Integer;
begin
  Result := Length(FOrbs);
end;

function TAetherScene.GetOrb(const AIndex: Integer): TOrb;
begin
  Result := FOrbs[AIndex];
end;

function TAetherScene.GetOrbWorldPosition(const AIndex: Integer): TPointF;
begin
  Result := FCenter + TPointF.Create(
    Cos(FOrbs[AIndex].Angle) * FOrbs[AIndex].Radius,
    Sin(FOrbs[AIndex].Angle) * FOrbs[AIndex].Radius * cOrbEllipseYScale);
end;

procedure TAetherScene.SetViewport(const AWidth, AHeight: Single);
begin
  FViewportWidth := AWidth;
  FViewportHeight := AHeight;
  FCenter := TPointF.Create(AWidth * 0.5, AHeight * 0.5);
end;

procedure TAetherScene.Initialize(const AWidth, AHeight: Single);
begin
  SetViewport(AWidth, AHeight);
  FMouse := FCenter;
  FTime := 0;
  FParticleCount := 0;
  SetLength(FParticles, cInitialParticleCount);
  InitializeOrbs;
  SeedInitialParticles;
  FInitialized := True;
end;

procedure TAetherScene.SetMousePosition(const APosition: TPointF);
begin
  FMouse := APosition;
end;

procedure TAetherScene.InitializeOrbs;
begin
  SetLength(FOrbs, Length(cOrbDefs));
  for var i := 0 to High(cOrbDefs) do
  begin
    FOrbs[i].Radius := cOrbDefs[i].Radius;
    FOrbs[i].Speed := cOrbDefs[i].Speed;
    FOrbs[i].BaseSize := cOrbDefs[i].BaseSize;
    FOrbs[i].Color := cOrbDefs[i].Color;
    FOrbs[i].Phase := cOrbDefs[i].Phase;
    FOrbs[i].Angle := Random * Pi * 2;
    FOrbs[i].Size := FOrbs[i].BaseSize;
  end;
end;

procedure TAetherScene.SeedInitialParticles;
begin
  for var i := 0 to cInitialParticleCount - 1 do
  begin
    SpawnParticle(
      TPointF.Create(FViewportWidth * Random, FViewportHeight * Random),
      cSeedParticleForce);
  end;
end;

procedure TAetherScene.RemoveParticleAt(const AIndex: Integer);
begin
  // Swap-remove: O(1), keeps dense prefix 0..Count-1
  Dec(FParticleCount);
  if AIndex < FParticleCount then
  begin
    FParticles[AIndex] := FParticles[FParticleCount];
  end;
end;

procedure TAetherScene.SpawnParticle(const ANear: TPointF; const AForce: Single);
var
  LParticle: TParticle;
  LAngle: Single;
begin
  if FParticleCount >= cMaxParticles then
  begin
    Exit;
  end;

  if FParticleCount >= Length(FParticles) then
  begin
    SetLength(FParticles, Min(cMaxParticles, Max(16, Length(FParticles) * 2)));
  end;

  LAngle := Random * Pi * 2;
  LParticle.Position := ANear + TPointF.Create(
    Cos(LAngle) * Random * cParticleSpawnJitter,
    Sin(LAngle) * Random * cParticleSpawnJitter);
  LParticle.Velocity := TPointF.Create(
    (Random - 0.5) * cParticleSpawnJitter * AForce,
    (Random - 0.5) * cParticleSpawnJitter * AForce);
  LParticle.MaxLife := cParticleMinLife + Random * cParticleLifeVariance;
  LParticle.Life := LParticle.MaxLife;
  LParticle.Size := cParticleMinSize + Random * cParticleSizeVariance;
  LParticle.Hue := Random;

  FParticles[FParticleCount] := LParticle;
  Inc(FParticleCount);
end;

procedure TAetherScene.Update(const ADeltaTime: Double);
var
  LParticle: TParticle;
  LDistance: Single;
  LForce: TPointF;
  LToMouse: TPointF;
  LToCenter: TPointF;
  LOrbIndex: Integer;
begin
  if not FInitialized then
  begin
    Exit;
  end;

  FTime := FTime + ADeltaTime;
  FCenter := TPointF.Create(FViewportWidth * 0.5, FViewportHeight * 0.5);

  for var i := 0 to High(FOrbs) do
  begin
    FOrbs[i].Angle := FOrbs[i].Angle + FOrbs[i].Speed * ADeltaTime;
    FOrbs[i].Size := FOrbs[i].BaseSize *
      (1 + cOrbPulseAmplitude * Sin(FTime * cOrbPulseFrequency + FOrbs[i].Phase));
  end;

  var i := FParticleCount - 1;
  while i >= 0 do
  begin
    LParticle := FParticles[i];
    LParticle.Life := LParticle.Life - ADeltaTime;

    if LParticle.Life <= 0 then
    begin
      RemoveParticleAt(i);
      Dec(i);
      Continue;
    end;

    LToMouse := LParticle.Position - FMouse;
    LDistance := LToMouse.Length;
    if (LDistance > cMinVectorLength) and (LDistance < cMouseInfluenceRadius) then
    begin
      LForce := LToMouse.Normalize *
        (1 - LDistance / cMouseInfluenceRadius) * cMouseRepulsionStrength;
      LParticle.Velocity := LParticle.Velocity + LForce * ADeltaTime;
    end;

    LToCenter := FCenter - LParticle.Position;
    if LToCenter.Length > cMinVectorLength then
    begin
      LParticle.Velocity := LParticle.Velocity +
        LToCenter.Normalize * cCenterPullStrength * ADeltaTime;
    end;

    LParticle.Velocity := LParticle.Velocity * (1 - cVelocityDamping * ADeltaTime);
    LParticle.Position := LParticle.Position + LParticle.Velocity * ADeltaTime;

    FParticles[i] := LParticle;
    Dec(i);
  end;

  if Random < cOrbSpawnChance then
  begin
    LOrbIndex := Random(Length(FOrbs));
    SpawnParticle(GetOrbWorldPosition(LOrbIndex), cOrbSpawnForce);
  end;
end;

end.