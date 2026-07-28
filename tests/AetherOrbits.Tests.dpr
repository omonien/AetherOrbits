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
  AetherOrbits.GameLoop in '..\src\AetherOrbits.GameLoop.pas',
  AetherOrbits.Scene in '..\src\AetherOrbits.Scene.pas',
  AetherOrbits.Scene.Renderer in '..\src\AetherOrbits.Scene.Renderer.pas',
  AetherOrbits.RuntimeInfo in '..\src\AetherOrbits.RuntimeInfo.pas',
  AetherOrbits.Main.Form in '..\src\AetherOrbits.Main.Form.pas' {FormMain},
  AetherOrbits.GameLoop.Tests in 'AetherOrbits.GameLoop.Tests.pas',
  AetherOrbits.Scene.Tests in 'AetherOrbits.Scene.Tests.pas',
  AetherOrbits.Main.Form.Smoke in 'AetherOrbits.Main.Form.Smoke.pas',
  AetherOrbits.RuntimeInfo.Tests in 'AetherOrbits.RuntimeInfo.Tests.pas';

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
