program rrbuild;
{$APPTYPE CONSOLE}
{$R 'studio.res' 'studio.rc'}

uses
  SysUtils,
  ZLib in '..\Zlib.pas',
  studio_tools in 'studio_tools.pas',
  Native in '..\Native.pas',
  WinBinFile in '..\WinBinFile.pas',
  DiskIO in '..\DiskIO.pas',
  QTThunkU in '..\QTThunkU.pas',
  unitPEFile in 'resourceutils\unitPEFile.pas',
  unitResourceDetails in 'resourceutils\unitResourceDetails.pas',
  md5 in 'md5\md5.pas',
  debug in 'debug.pas';

var
   i : Integer;
   Count : Integer;
begin
   UseWriteln;

   Log('rawwrite rrbuild for windows version ' + AppVersion + '.  Written by John Newbigin <jn@it.swin.edu.au>');
   Log('This program is covered by the GPL.  See copying.txt for details');

   Count := 0;
   for i := 1 to ParamCount do
   begin
      if FileExists(ParamStr(i)) then
      begin
         CreateExe(ParamStr(i));
         Count := Count + 1;
      end
      else
      begin
         Log('File not found ' + ParamStr(i));
      end;
   end;

   if Count = 0 then
   begin
      Log('Usage: rrbuild configfile.txt [comfigfile2.txt ...]');
   end;

   writeln('Press enter');
   readln;

end.
