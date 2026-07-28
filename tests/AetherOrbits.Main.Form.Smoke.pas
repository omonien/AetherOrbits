/// <summary>
/// AetherOrbits.Main.Form.Smoke
/// Form smoke test – constructs TFormMain to catch invalid FMX properties.
/// </summary>
///
/// <remarks>
/// A successful compile does not prove every property in the .fmx is valid.
/// Constructing the form once catches EReadError from the streaming system.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit AetherOrbits.Main.Form.Smoke;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMainFormSmokeTests = class
  public
    [Test]
    procedure FormMain_CreatesAndDestroys;
  end;

implementation

uses
  System.SysUtils,
  FMX.Forms,
  FMX.Types,
  FMX.Skia,
  AetherOrbits.Main.Form;

procedure TMainFormSmokeTests.FormMain_CreatesAndDestroys;
var
  LForm: TFormMain;
begin
  GlobalUseSkia := True;
  if not Assigned(Application) then
  begin
    raise Exception.Create('FMX Application not available');
  end;

  Application.Initialize;
  LForm := TFormMain.Create(nil);
  try
    Assert.IsNotNull(LForm, 'Form must construct');
    Assert.AreEqual('Aether Orbits - FMX + Skia Game Loop Demo', LForm.Caption);
  finally
    FreeAndNil(LForm);
  end;
end;

end.