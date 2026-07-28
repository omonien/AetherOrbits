/// <summary>
/// AetherOrbits.GameLoop
/// Isolated, reusable fixed-timestep game loop for FMX (Delphi 13+).
/// </summary>
///
/// <remarks>
/// Derives from TAnimation and overrides ProcessAnimation so the loop is
/// driven by the Display Link Service (VSync). This is the modern,
/// framework-native way to run a game loop under FireMonkey without third-
/// party libraries.
///
/// Pattern: fixed timestep for update/physics (Glenn Fiedler), render once
/// per frame after updates.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit AetherOrbits.GameLoop;

interface

uses
  // System
  System.Classes,
  System.Diagnostics,
  System.SysUtils,
  // FMX
  FMX.Types,
  FMX.Ani;

type
  /// <summary>
  /// Called on every fixed timestep tick. Put game logic / physics here.
  /// </summary>
  TGameUpdateEvent = procedure(const ADeltaTime: Double) of object;

  /// <summary>
  /// Called once per frame after updates. Put invalidation / render trigger here.
  /// </summary>
  TGameRenderEvent = procedure of object;

  /// <summary>
  /// High-precision, VSync-driven game loop based on TAnimation.
  /// Uses the Display Link Service of Delphi 13.
  /// </summary>
  TGameLoop = class(TAnimation)
  private
    FStopwatch: TStopwatch;
    FLastTime: Double;
    FAccumulator: Double;
    FFixedTimeStep: Double;
    FOnUpdate: TGameUpdateEvent;
    FOnRender: TGameRenderEvent;
    FMaxFrameTime: Double;
  protected
    procedure ProcessAnimation; override;
  public
    constructor Create(AOwner: TComponent); override;

    /// <summary>
    /// Starts the loop (resets timing, sets Loop, starts the animation).
    /// </summary>
    procedure StartLoop;

    /// <summary>
    /// Stops the loop.
    /// </summary>
    procedure StopLoop;

    /// <summary>
    /// Fixed timestep for physics/logic (default: 1/60 s).
    /// </summary>
    property FixedTimeStep: Double read FFixedTimeStep write FFixedTimeStep;

    /// <summary>
    /// Maximum allowed frame time in seconds (spiral-of-death guard).
    /// </summary>
    property MaxFrameTime: Double read FMaxFrameTime write FMaxFrameTime;

    /// <summary>
    /// Invoked with a fixed delta (may run multiple times per frame).
    /// </summary>
    property OnUpdate: TGameUpdateEvent read FOnUpdate write FOnUpdate;

    /// <summary>
    /// Invoked once per frame after updates. Ideal for invalidating the render target.
    /// </summary>
    property OnRender: TGameRenderEvent read FOnRender write FOnRender;
  end;

implementation

const
  /// <summary>Default physics/logic step: 60 Hz.</summary>
  cDefaultFixedTimeStep = 1 / 60;
  /// <summary>Default clamp for a single frame (100 ms).</summary>
  cDefaultMaxFrameTime = 0.1;
  /// <summary>Practically infinite TAnimation duration while Loop is True.</summary>
  cInfiniteAnimationDuration = 1E10;

{ TGameLoop }

constructor TGameLoop.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFixedTimeStep := cDefaultFixedTimeStep;
  FMaxFrameTime := cDefaultMaxFrameTime;
  FAccumulator := 0;
  FLastTime := 0;
  FStopwatch := TStopwatch.StartNew;

  // Keep the animation running continuously under the Display Link Service
  Loop := True;
  Duration := cInfiniteAnimationDuration;
end;

procedure TGameLoop.StartLoop;
begin
  FStopwatch.Reset;
  FStopwatch.Start;
  FLastTime := 0;
  FAccumulator := 0;
  Start;
end;

procedure TGameLoop.StopLoop;
begin
  Stop;
end;

procedure TGameLoop.ProcessAnimation;
var
  LNow: Double;
  LFrameTime: Double;
begin
  LNow := FStopwatch.Elapsed.TotalSeconds;
  LFrameTime := LNow - FLastTime;
  FLastTime := LNow;

  // Guard against large time jumps (debugger, Alt-Tab, etc.)
  if LFrameTime > FMaxFrameTime then
  begin
    LFrameTime := FMaxFrameTime;
  end;

  FAccumulator := FAccumulator + LFrameTime;

  // Fixed timestep – classic Glenn Fiedler pattern
  while FAccumulator >= FFixedTimeStep do
  begin
    if Assigned(FOnUpdate) then
    begin
      FOnUpdate(FFixedTimeStep);
    end;

    FAccumulator := FAccumulator - FFixedTimeStep;
  end;

  // Render / invalidate once per frame
  if Assigned(FOnRender) then
  begin
    FOnRender;
  end;
end;

end.