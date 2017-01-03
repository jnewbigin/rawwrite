unit debug;

{$IFDEF FPC}
{$MODE Delphi}
{$ENDIF}

interface

uses Windows, LCLIntf, LCLType, LMessages;

procedure Log(S : String);
type DebugEvent = procedure (S : String) of object;
procedure SetDebug(d : DebugEvent);
procedure UseWriteln;
procedure UseStdError;
procedure HexDump(P : PChar; Length : Integer);



type TWriteLine = class
public
   procedure WriteLine(S : String);
end;

type TStdError = class
private
   h : THandle;
public
   constructor Create;
   procedure Write(S : String);
   procedure WriteLine(S : String);
end;

function IsDebuggerPresent : Boolean;

var
   stderr : TStdError;

implementation

uses WinIOCTL, sysutils;

var
   fOnDebug : DebugEvent;

type TIsDebuggerPresent = function : BOOL; stdcall;

procedure Log(S : String);
begin
   if Assigned(fOnDebug) then
   begin
      fOnDebug(s);
   end;
end;

procedure SetDebug(d : DebugEvent);
begin
   fOnDebug := d;
end;

procedure TWriteLine.WriteLine(S : String);
begin
{$IFDEF FPC}
   Writeln(S + #13);
{$ELSE}
   Writeln(Output, S);
{$ENDIF}
end;

constructor TStdError.Create;
begin
   h := GetStdHandle(STD_ERROR_HANDLE);
end;

procedure TStdError.Write(S : String);
var
   Done : DWORD;
begin
   WriteFile2(h, PChar(S), Length(S), done, nil);
end;

procedure TStdError.WriteLine(S : String);
var
   Done : DWORD;
begin
   S := S + #13 + #10;
   WriteFile2(h, PChar(S), Length(S), done, nil);
end;

procedure UseWriteln;
var
   wl : TWriteLine;
begin
   wl := TWriteLine.Create;
   SetDebug(wl.WriteLine);
end;

procedure UseStdError;
begin
   stderr := TStdError.Create;
   SetDebug(stderr.WriteLine);
end;

function IsDebuggerPresent : Boolean;
var
   hModule : hInst;
//   Error : DWORD;
   JIsDebuggerPresent : TIsDebuggerPresent;
   P : Pointer;
begin
   Result := False;

   // see if we can get IsDebuggerPresent from kernel32.dll

   hModule := GetModuleHandle('kernel32.dll');
   if hModule = 0 then
   begin
      // wininet is not yet loaded...
      hModule := LoadLibrary('kernel32.dll');
      {if hModule = 0 then
      begin
         Error := GetLastError;
         //raise Exception.Create('Error loading Windows Internet Library.  ' + SysErrorMessage(Error));
      end;}
   end;

   if hModule <> 0 then
   begin
      P := GetProcAddress(hModule, 'IsDebuggerPresent');
      if P = nil then
      begin
         //raise Exception.Create('Could not find procedure ' + ProcName);
      end
      else
      begin
         JIsDebuggerPresent := p;
         Result := JIsDebuggerPresent;
      end;
   end;

end;

procedure HexDump(P : PChar; Length : Integer);
var

   S  : String;
   S2 : String;
   i  : Integer;
begin
   S := '0000 ';
   for i := 0 to Length - 1 do
   begin
      S := S + IntToHex(Ord(P[i]), 2);
      if not (ord(P[i]) in [0, 7, 8, 9, 10, 13]) then
      begin
         S2 := S2 + P[i];
      end
      else
      begin
         S2 := S2 + ' ';
      end;
      S := S + ' ';
      if System.Length(S) >= 52 then
      begin
         Log(S + ' ' + S2);
         S := IntToHex(i + 1, 4) + ' ';
         s2 := '';
      end;
   end;
end;



end.
