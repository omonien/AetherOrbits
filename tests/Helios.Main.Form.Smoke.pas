/// <summary>
/// Helios.Main.Form.Smoke
/// Form smoke test – constructs TFormHeliosMain to catch invalid FMX properties.
/// </summary>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit Helios.Main.Form.Smoke;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  THeliosMainFormSmokeTests = class
  public
    [Test]
    procedure FormHeliosMain_CreatesAndDestroys;
  end;

implementation

uses
  System.SysUtils,
  System.UITypes,
  FMX.Forms,
  FMX.Types,
  FMX.Skia,
  Helios.Main.Form;

procedure THeliosMainFormSmokeTests.FormHeliosMain_CreatesAndDestroys;
var
  LForm: TFormHeliosMain;
begin
  GlobalUseSkia := True;
  if not Assigned(Application) then
  begin
    raise Exception.Create('FMX Application not available');
  end;

  Application.Initialize;
  LForm := TFormHeliosMain.Create(nil);
  try
    Assert.IsNotNull(LForm, 'Form must construct');
    Assert.AreEqual('Helios - Solar System Demo (FMX + Skia)', LForm.Caption);

    Assert.IsNotNull(LForm.LayoutToolbar, 'LayoutToolbar missing from FMX');
    Assert.IsNotNull(LForm.LayoutScene, 'LayoutScene missing from FMX');
    Assert.IsNotNull(LForm.RectSpeed1, 'Speed 1x segment missing from FMX');
    Assert.IsNotNull(LForm.RectPause, 'Pause control missing from FMX');
    Assert.IsTrue(LForm.LayoutToolbar.Visible, 'LayoutToolbar must be visible');
    Assert.IsTrue(LForm.LayoutToolbar.Height >= 40, 'LayoutToolbar height too small');
    Assert.AreEqual('Speed', LForm.LabelSpeed.Text);
    Assert.AreEqual('Pause', LForm.LabelPause.Text);
    Assert.AreEqual(Cardinal($FF2563A8), Cardinal(LForm.RectSpeed1.Fill.Color),
      'Default speed segment should be selected (1x)');
  finally
    FreeAndNil(LForm);
  end;
end;

end.
