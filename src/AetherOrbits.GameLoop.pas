/// <summary>
/// AetherOrbits.GameLoop
/// Standalone, reusable fixed-timestep game loop for FMX (Delphi 13+).
/// </summary>
///
/// <remarks>
/// <para>
/// <b>Independence:</b> This unit has no knowledge of the Aether Orbits demo,
/// scene, Skia, or any form. Dependencies are only System.* and FMX.Ani /
/// FMX.Types (for TAnimation). Copy this single unit into any FMX project
/// and wire OnUpdate / OnRender — that is all that is required.
/// </para>
/// <para>
/// <b>The core idea (Delphi 13 / Embarcadero FMX):</b> derive from
/// <c>TAnimation</c> and override <c>ProcessAnimation</c>.
/// From Delphi 13, FMX drives animations through the platform
/// <b>Display Link Service</b> (VSync / display refresh). The framework
/// calls <c>ProcessAnimation</c> on each display-link tick for every
/// running animation. That virtual method is therefore the official,
/// framework-native hook for continuous per-frame work — without a
/// TTimer, a busy thread, Application.OnIdle hacks, or third-party loops.
/// </para>
/// <para>
/// <b>FMX requirement:</b> <c>TAnimation.Start</c> only subscribes to the
/// Display Link when <c>Root &lt;&gt; nil</c>. If <c>Root</c> is nil (no parent
/// chain to a form), FMX runs a one-shot "immediate" animation and stops —
/// the scene freezes after the first paint. This unit therefore parents
/// itself to the owner when the owner is a <c>TFmxObject</c> (typically the
/// form). Call <c>StartLoop</c> when the form is visible (e.g. OnShow);
/// starting while the parent control is not visible is a no-op in FMX.
/// </para>
/// <para>
/// Everything else in this unit (stopwatch, accumulator, fixed timestep,
/// max-frame clamp) is built <i>on top of</i> that override. The override
/// is the integration point Embarcadero gives us; the fixed-timestep
/// pattern (Glenn Fiedler) is the portable game-loop discipline we apply
/// inside it.
/// </para>
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
  // FMX (TAnimation only — no forms, no Skia, no demo types)
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
  /// </summary>
  /// <remarks>
  /// Standalone drop-in: no coupling to any particular scene or renderer.
  /// The essential mechanism is the <c>ProcessAnimation</c> override, which
  /// the Delphi 13 FMX Display Link Service invokes on each VSync-aligned
  /// tick. Requires a parent in the FMX tree (Root &lt;&gt; nil) so Start
  /// subscribes to Display Link instead of the immediate one-shot path.
  /// </remarks>
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
    /// <summary>
    /// <b>Central hook of this unit.</b> Override of <c>TAnimation.ProcessAnimation</c>.
    /// </summary>
    /// <remarks>
    /// Embarcadero FMX (Delphi 13+) calls this method from the Display Link
    /// Service for each active animation, synchronized with the display
    /// refresh (VSync). By putting the game-loop body here we:
    /// <list type="bullet">
    ///   <item>run at the native display cadence (no timer drift),</item>
    ///   <item>stay inside the official FMX animation pipeline,</item>
    ///   <item>avoid custom threads or polling loops.</item>
    /// </list>
    /// Inside the override we measure real elapsed time, clamp spikes,
    /// run zero-or-more fixed-step <c>OnUpdate</c> calls, then fire
    /// <c>OnRender</c> once per display tick.
    /// </remarks>
    procedure ProcessAnimation; override;
  public
    /// <summary>
    /// Creates the loop. If AOwner is a TFmxObject (e.g. the form), sets
    /// Parent so Root is available for Display Link subscription.
    /// </summary>
    constructor Create(AOwner: TComponent); override;

    /// <summary>
    /// Starts the loop (resets timing, starts the animation / Display Link).
    /// Prefer calling when the host form is visible (OnShow).
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

  // TAnimation.Start only uses Display Link when Root <> nil. Without Parent,
  // Root is nil and FMX runs a one-shot "immediate" animation then stops.
  if AOwner is TFmxObject then
  begin
    Parent := TFmxObject(AOwner);
  end;

  // Loop + huge Duration keep TAnimation "running" so Display Link keeps
  // calling ProcessAnimation; Duration is not the game-loop period.
  Loop := True;
  Duration := cInfiniteAnimationDuration;
end;

procedure TGameLoop.StartLoop;
begin
  FStopwatch.Reset;
  FStopwatch.Start;
  FLastTime := 0;
  FAccumulator := 0;

  // Idempotent restart: Stop unsubscribes Display Link if already running
  if Running then
  begin
    Stop;
  end;

  // Registers with FMX animation / Display Link (needs Root <> nil)
  Start;
end;

procedure TGameLoop.StopLoop;
begin
  if Running then
  begin
    Stop;
  end;
end;

procedure TGameLoop.ProcessAnimation;
// =============================================================================
// CORE OF THIS UNIT — called by FMX (Delphi 13 Display Link) each VSync tick.
// This override is the official framework hook; do not replace it with a
// TTimer or a thread if the goal is the native D13 approach.
// =============================================================================
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

  // Fixed timestep (Glenn Fiedler) — portable discipline on top of the hook
  while FAccumulator >= FFixedTimeStep do
  begin
    if Assigned(FOnUpdate) then
    begin
      FOnUpdate(FFixedTimeStep);
    end;

    FAccumulator := FAccumulator - FFixedTimeStep;
  end;

  // Once per display tick: consumers typically invalidate a paint surface
  if Assigned(FOnRender) then
  begin
    FOnRender;
  end;
end;

end.