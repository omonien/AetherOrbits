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

    // Preferred FPS bar must stream from FMX and stay visible above the scene.
    Assert.IsNotNull(LForm.PanelPreferred, 'PanelPreferred missing from FMX');
    Assert.IsNotNull(LForm.LayoutScene, 'LayoutScene missing from FMX');
    Assert.IsTrue(LForm.PanelPreferred.Visible, 'PanelPreferred must be visible');
    Assert.IsTrue(LForm.PanelPreferred.Height >= 40, 'PanelPreferred height too small');
    Assert.IsTrue(LForm.RadioPreferred60.IsChecked, 'Default preferred FPS radio is 60');
  finally
    FreeAndNil(LForm);
  end;
end;

end.