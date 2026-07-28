/// <summary>
/// AetherOrbits.Scene
/// Simulation model for the Aether Orbits demo (orbs + particles).
/// </summary>
///
/// <remarks>
/// Contains only game state and fixed-timestep update logic. No UI, no
/// rendering. The form owns a TAetherScene and drives Update from TGameLoop;
/// AetherOrbits.Scene.Renderer draws the state via Skia.
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
  System.Math,
  System.Generics.Collections;

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
  /// Demo scene: orbs, particles, and mouse interaction state.
  /// </summary>
  TAetherScene = class
  private
    FParticles: TList<TParticle>;
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
    function GetParticleCount: Integer;
    function GetOrbCount: Integer;
    function GetParticle(const AIndex: Integer): TParticle;
    function GetOrb(const AIndex: Integer): TOrb;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    /// Sets viewport size and builds the initial scene (orbs + particles).
    /// Safe to call again after a resize; re-centers without resetting entities.
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

    property Time: Double read FTime;
    property Center: TPointF read FCenter;
    property Mouse: TPointF read FMouse;
    property ViewportWidth: Single read FViewportWidth;
    property ViewportHeight: Single read FViewportHeight;
    property ParticleCount: Integer read GetParticleCount;
    property OrbCount: Integer read GetOrbCount;
    property Particles[const AIndex: Integer]: TParticle read GetParticle;
    property Orbs[const AIndex: Integer]: TOrb read GetOrb;
  end;

implementation

const
  cOrbCount = 5;
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
  cOrbEllipseYScale = 0.72;
  cParticleSpawnJitter = 40.0;
  cParticleMinLife = 1.8;
  cParticleLifeVariance = 2.5;
  cParticleMinSize = 1.2;
  cParticleSizeVariance = 2.8;

{ TAetherScene }

constructor TAetherScene.Create;
begin
  inherited Create;
  FParticles := TList<TParticle>.Create;
  FTime := 0;
  FInitialized := False;
  FViewportWidth := 0;
  FViewportHeight := 0;
  FMouse := TPointF.Zero;
  FCenter := TPointF.Zero;
end;

destructor TAetherScene.Destroy;
begin
  FreeAndNil(FParticles);
  inherited;
end;

function TAetherScene.GetParticleCount: Integer;
begin
  Result := FParticles.Count;
end;

function TAetherScene.GetOrbCount: Integer;
begin
  Result := Length(FOrbs);
end;

function TAetherScene.GetParticle(const AIndex: Integer): TParticle;
begin
  Result := FParticles[AIndex];
end;

function TAetherScene.GetOrb(const AIndex: Integer): TOrb;
begin
  Result := FOrbs[AIndex];
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
  FParticles.Clear;
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
  SetLength(FOrbs, cOrbCount);

  FOrbs[0].Radius := 140;
  FOrbs[0].Speed := 0.35;
  FOrbs[0].BaseSize := 28;
  FOrbs[0].Color := $FF00E5FF;
  FOrbs[0].Phase := 0.0;

  FOrbs[1].Radius := 210;
  FOrbs[1].Speed := -0.22;
  FOrbs[1].BaseSize := 18;
  FOrbs[1].Color := $FFFF2E9F;
  FOrbs[1].Phase := 1.2;

  FOrbs[2].Radius := 280;
  FOrbs[2].Speed := 0.15;
  FOrbs[2].BaseSize := 22;
  FOrbs[2].Color := $FFFFD166;
  FOrbs[2].Phase := 2.8;

  FOrbs[3].Radius := 175;
  FOrbs[3].Speed := -0.41;
  FOrbs[3].BaseSize := 14;
  FOrbs[3].Color := $FF7B61FF;
  FOrbs[3].Phase := 4.1;

  FOrbs[4].Radius := 320;
  FOrbs[4].Speed := 0.09;
  FOrbs[4].BaseSize := 16;
  FOrbs[4].Color := $FF00FFA3;
  FOrbs[4].Phase := 0.7;

  for var i := 0 to High(FOrbs) do
  begin
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

procedure TAetherScene.SpawnParticle(const ANear: TPointF; const AForce: Single);
var
  LParticle: TParticle;
  LAngle: Single;
begin
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
  FParticles.Add(LParticle);
end;

procedure TAetherScene.Update(const ADeltaTime: Double);
var
  LParticle: TParticle;
  LOrbPos: TPointF;
  LDistance: Single;
  LForce: TPointF;
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

  for var i := FParticles.Count - 1 downto 0 do
  begin
    LParticle := FParticles[i];
    LParticle.Life := LParticle.Life - ADeltaTime;

    if LParticle.Life <= 0 then
    begin
      FParticles.Delete(i);
      Continue;
    end;

    LDistance := LParticle.Position.Distance(FMouse);
    if LDistance < cMouseInfluenceRadius then
    begin
      LForce := (LParticle.Position - FMouse).Normalize *
        (1 - LDistance / cMouseInfluenceRadius) * cMouseRepulsionStrength;
      LParticle.Velocity := LParticle.Velocity + LForce * ADeltaTime;
    end;

    LParticle.Velocity := LParticle.Velocity +
      (FCenter - LParticle.Position).Normalize * cCenterPullStrength * ADeltaTime;
    LParticle.Velocity := LParticle.Velocity * (1 - cVelocityDamping * ADeltaTime);
    LParticle.Position := LParticle.Position + LParticle.Velocity * ADeltaTime;

    FParticles[i] := LParticle;
  end;

  if Random < cOrbSpawnChance then
  begin
    LOrbIndex := Random(Length(FOrbs));
    LOrbPos := FCenter + TPointF.Create(
      Cos(FOrbs[LOrbIndex].Angle) * FOrbs[LOrbIndex].Radius,
      Sin(FOrbs[LOrbIndex].Angle) * FOrbs[LOrbIndex].Radius * cOrbEllipseYScale);
    SpawnParticle(LOrbPos, cOrbSpawnForce);
  end;
end;

end.