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
/// running animation.
/// </para>
/// <para>
/// <b>Three different "FPS" concepts (do not conflate them):</b>
/// </para>
/// <para>
/// 1. <b>Display-link / VSync rate</b> — how often FMX calls
/// <c>ProcessAnimation</c>. On iOS/macOS this is CADisplayLink (often respects
/// <c>GlobalPreferredFramesPerSecond</c>). On Windows with DWM composition
/// enabled, FMX uses <c>DwmFlush</c> and is effectively locked to the monitor
/// refresh (typically 60 Hz); the preferred interval is largely ignored there.
/// </para>
/// <para>
/// 2. <b>Preferred FPS</b> (<c>GlobalPreferredFramesPerSecond</c> in FMX.Types)
/// — a *request* for how often this loop should run update+render work. The
/// demo UI exposes 30/60/120. When the platform still ticks faster (Windows
/// DWM at 60 while preferred is 30), this unit <b>paces</b>: it returns early
/// from <c>ProcessAnimation</c> until at least 1/preferred seconds of wall
/// time have elapsed since the last processed frame. That is what makes
/// "30" work on Windows. Preferred can never push the rate *above* the
/// display-link ceiling (e.g. preferred 120 on a 60 Hz panel stays ~60).
/// </para>
/// <para>
/// 3. <b>FixedTimeStep</b> (default 1/60) — simulation/physics step size only.
/// Independent of preferred and of display Hz. Multiple fixed updates may run
/// per processed frame after a hitch; render happens once per processed frame.
/// Do not change FixedTimeStep when the user picks Preferred FPS.
/// </para>
/// <para>
/// <b>FMX requirement:</b> <c>TAnimation.Start</c> only subscribes to the
/// Display Link when <c>Root &lt;&gt; nil</c>. This unit parents itself to the
/// owner when the owner is a <c>TFmxObject</c>. <c>StartLoop</c> raises if
/// Root is still nil (fail loud instead of a one-shot freeze). Call
/// <c>StartLoop</c> when the form is visible (e.g. OnShow).
/// </para>
/// <para>
/// Timing uses an internal <c>TStopwatch</c> (not FMX animation NormalizedTime)
/// so the fixed-timestep accumulator is independent of TAnimation.Duration.
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
  System.Math,
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
  /// Paces work to GlobalPreferredFramesPerSecond when the display link is faster.
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
    FPaceToPreferredFps: Boolean;
  protected
    /// <summary>
    /// Central hook: FMX Display Link calls this each VSync tick.
    /// May no-op when pacing to Preferred FPS (see unit remarks).
    /// </summary>
    procedure ProcessAnimation; override;
  public
    constructor Create(AOwner: TComponent); override;

    /// <summary>
    /// Starts the loop. Raises if Root is nil (Parent not in FMX tree).
    /// Prefer calling when the host form is visible (OnShow).
    /// </summary>
    procedure StartLoop;

    /// <summary>
    /// Stops the loop.
    /// </summary>
    procedure StopLoop;

    /// <summary>
    /// Simulation step in seconds (default 1/60). Not the display or preferred rate.
    /// </summary>
    property FixedTimeStep: Double read FFixedTimeStep write FFixedTimeStep;

    /// <summary>
    /// Clamp for spiral-of-death after long pauses (debugger, Alt-Tab).
    /// </summary>
    property MaxFrameTime: Double read FMaxFrameTime write FMaxFrameTime;

    /// <summary>
    /// When True (default), skip update/render until wall time reaches
    /// 1/GlobalPreferredFramesPerSecond. Needed so Preferred FPS works on
    /// Windows DWM (display link stays at monitor Hz). Set False in unit tests
    /// that fire ProcessAnimation back-to-back without real-time delays.
    /// </summary>
    property PaceToPreferredFps: Boolean read FPaceToPreferredFps write FPaceToPreferredFps;

    property OnUpdate: TGameUpdateEvent read FOnUpdate write FOnUpdate;
    property OnRender: TGameRenderEvent read FOnRender write FOnRender;
  end;

implementation

const
  cDefaultFixedTimeStep = 1 / 60;
  cDefaultMaxFrameTime = 0.1;
  cInfiniteAnimationDuration = 1E10;
  // Allow tiny jitter below the ideal period so 60 Hz display + preferred 60
  // still processes every VSync instead of occasionally dropping a frame.
  cPreferredPaceSlack = 0.92;

resourcestring
  rsGameLoopNeedsRoot =
    'TGameLoop.StartLoop requires Root <> nil (Parent in the FMX tree) so the ' +
    'Display Link can drive ProcessAnimation. Pass the form as Owner or set ' +
    'Parent before StartLoop.';

{ TGameLoop }

constructor TGameLoop.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFixedTimeStep := cDefaultFixedTimeStep;
  FMaxFrameTime := cDefaultMaxFrameTime;
  FPaceToPreferredFps := True;
  FAccumulator := 0;
  FLastTime := 0;
  FStopwatch := TStopwatch.StartNew;

  // Display Link subscription requires Root <> nil
  if AOwner is TFmxObject then
  begin
    Parent := TFmxObject(AOwner);
  end;

  Loop := True;
  Duration := cInfiniteAnimationDuration;
end;

procedure TGameLoop.StartLoop;
begin
  if Root = nil then
  begin
    raise EInvalidOpException.Create(rsGameLoopNeedsRoot);
  end;

  FStopwatch.Reset;
  FStopwatch.Start;
  FLastTime := 0;
  FAccumulator := 0;

  if Running then
  begin
    Stop;
  end;

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
// CORE: called by FMX (Delphi 13 Display Link) each VSync / display-link tick.
//
// Call rate ≠ work rate:
//   - Display link may fire at monitor Hz (Windows DWM) or preferred CADisplayLink rate.
//   - We optionally pace work to GlobalPreferredFramesPerSecond (see unit remarks).
//   - FixedTimeStep only sizes OnUpdate; it does not control this call rate.
var
  LNow: Double;
  LFrameTime: Double;
  LMinFrameTime: Double;
  LPreferredFps: Integer;
begin
  LNow := FStopwatch.Elapsed.TotalSeconds;
  LFrameTime := LNow - FLastTime;

  // --- Preferred-FPS pacing -------------------------------------------------
  // FMX.Types.GlobalPreferredFramesPerSecond is a *request*. On iOS/macOS the
  // Display Link often honours it; on Windows with DWM, FMX.DisplayLink.Default
  // waits on DwmFlush and keeps calling us at display refresh (~60/120), even
  // when preferred is 30. Without this early exit, the footer would stay at ~60
  // FPS while the radio already shows Preferred: 30.
  //
  // Strategy: do not advance FLastTime / accumulator until enough wall time
  // has passed. The next tick then sees a larger LFrameTime and runs normally
  // (fixed-step catch-up still applies via MaxFrameTime).
  //
  // FLastTime = 0 after StartLoop → always process the first frame.
  if FPaceToPreferredFps and (FLastTime > 0) then
  begin
    LPreferredFps := GlobalPreferredFramesPerSecond;
    if LPreferredFps < 1 then
    begin
      LPreferredFps := 60;
    end;
    LMinFrameTime := (1.0 / LPreferredFps) * cPreferredPaceSlack;
    if LFrameTime < LMinFrameTime then
    begin
      Exit;
    end;
  end;
  // --------------------------------------------------------------------------

  FLastTime := LNow;

  if LFrameTime > FMaxFrameTime then
  begin
    LFrameTime := FMaxFrameTime;
  end;

  FAccumulator := FAccumulator + LFrameTime;

  // Fixed timestep: simulation rate, independent of preferred / display Hz.
  while FAccumulator >= FFixedTimeStep do
  begin
    if Assigned(FOnUpdate) then
    begin
      FOnUpdate(FFixedTimeStep);
    end;
    FAccumulator := FAccumulator - FFixedTimeStep;
  end;

  if Assigned(FOnRender) then
  begin
    FOnRender;
  end;
end;

end.
