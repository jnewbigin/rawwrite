program rawwritewin;

{$MODE Delphi}

uses
  Forms, Interfaces,
  rawwrite in 'rawwrite.pas' {MainForm},
  DiskIO in 'DiskIO.pas',
  QTThunkU in 'QTThunkU.pas',
  BlockDev in 'BlockDev.pas',
  debug in 'studio\debug.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'RawWrite for Windows';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
