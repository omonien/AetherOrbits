/// <summary>
/// AetherOrbits.Tests
/// DUnitX test runner for Aether Orbits.
/// </summary>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

program AetherOrbits.Tests;

{$APPTYPE CONSOLE}

{$STRONGLINKTYPES ON}
{$R *.res}

uses
  System.SysUtils,
  FMX.Forms,
  FMX.Types,
  FMX.Skia,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.XML.NUnit,
  FMXAnimation.GameLoop in '..\src\FMXAnimation.GameLoop.pas',
  FMXAnimation.SystemInfo in '..\src\FMXAnimation.SystemInfo.pas',
  FMXAnimation.Stats.Hud in '..\src\FMXAnimation.Stats.Hud.pas',
  FMXAnimation.DemoShell in '..\src\FMXAnimation.DemoShell.pas',
  AetherOrbits.Scene in '..\src\AetherOrbits\AetherOrbits.Scene.pas',
  AetherOrbits.Scene.Renderer in '..\src\AetherOrbits\AetherOrbits.Scene.Renderer.pas',
  AetherOrbits.Main.Form in '..\src\AetherOrbits\AetherOrbits.Main.Form.pas' {FormMain},
  FMXAnimation.GameLoop.Tests in 'FMXAnimation.GameLoop.Tests.pas',
  AetherOrbits.Scene.Tests in 'AetherOrbits.Scene.Tests.pas',
  AetherOrbits.Main.Form.Smoke in 'AetherOrbits.Main.Form.Smoke.pas',
  FMXAnimation.SystemInfo.Tests in 'FMXAnimation.SystemInfo.Tests.pas',
  Helios.Scene in '..\src\Helios\Helios.Scene.pas',
  Helios.Scene.Renderer in '..\src\Helios\Helios.Scene.Renderer.pas',
  Helios.Main.Form in '..\src\Helios\Helios.Main.Form.pas' {FormHeliosMain},
  Helios.Scene.Tests in 'Helios.Scene.Tests.pas',
  Helios.Main.Form.Smoke in 'Helios.Main.Form.Smoke.pas';

var
  LRunner: ITestRunner;
  LResults: IRunResults;
  LLogger: ITestLogger;
  LNUnitLogger: ITestLogger;
begin
  try
    GlobalUseSkia := True;
    Application.Initialize;

    TDUnitX.CheckCommandLine;

    LRunner := TDUnitX.CreateRunner;
    LRunner.UseRTTI := True;
    LRunner.FailsOnNoAsserts := False;

    LLogger := TDUnitXConsoleLogger.Create(True);
    LRunner.AddLogger(LLogger);

    LNUnitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    LRunner.AddLogger(LNUnitLogger);

    LResults := LRunner.Execute;

    if not LResults.AllPassed then
    begin
      System.ExitCode := 1;
    end
    else
    begin
      System.ExitCode := 0;
    end;
  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 1;
    end;
  end;
end.
