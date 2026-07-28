/// <summary>
/// AetherOrbits.RuntimeInfo.Tests
/// </summary>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit AetherOrbits.RuntimeInfo.Tests;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  AetherOrbits.RuntimeInfo;

type
  [TestFixture]
  TRuntimeInfoTests = class
  public
    [Test]
    procedure HostPlatformLabel_IsNonEmpty;
    [Test]
    procedure RenderBackendLabel_IsNonEmpty;
  end;

implementation

procedure TRuntimeInfoTests.HostPlatformLabel_IsNonEmpty;
var
  LLabel: string;
begin
  LLabel := GetHostPlatformLabel;
  Assert.IsTrue(LLabel <> '', 'Platform label empty');
  Assert.IsTrue(Pos('Win', LLabel) > 0, 'Expected Windows arch token in label');
end;

procedure TRuntimeInfoTests.RenderBackendLabel_IsNonEmpty;
begin
  Assert.IsTrue(GetActiveRenderBackendLabel <> '', 'Backend label empty');
end;

end.