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
    /// Central hook: FMX Display Link calls this each VSync tick.
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

    property FixedTimeStep: Double read FFixedTimeStep write FFixedTimeStep;
    property MaxFrameTime: Double read FMaxFrameTime write FMaxFrameTime;
    property OnUpdate: TGameUpdateEvent read FOnUpdate write FOnUpdate;
    property OnRender: TGameRenderEvent read FOnRender write FOnRender;
  end;

implementation

const
  cDefaultFixedTimeStep = 1 / 60;
  cDefaultMaxFrameTime = 0.1;
  cInfiniteAnimationDuration = 1E10;

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
// CORE: called by FMX (Delphi 13 Display Link) each VSync tick.
var
  LNow: Double;
  LFrameTime: Double;
begin
  LNow := FStopwatch.Elapsed.TotalSeconds;
  LFrameTime := LNow - FLastTime;
  FLastTime := LNow;

  if LFrameTime > FMaxFrameTime then
  begin
    LFrameTime := FMaxFrameTime;
  end;

  FAccumulator := FAccumulator + LFrameTime;

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