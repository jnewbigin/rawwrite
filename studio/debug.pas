unit debug;

{$IFDEF FPC}
{$MODE Delphi}
{$ENDIF}

// $Header: /home/cso/jnewbigin/cvsroot/rawwrite/studio/debug.pas,v 1.2 2005/12/05 08:26:02 jnewbigin Exp $

interface

uses windows;

procedure Log(S : String);
type DebugEvent = procedure (S : String) of object;
procedure SetDebug(d : DebugEvent);
procedure UseWriteln;
procedure UseStdError;


type TWriteLine = class
public
   procedure WriteLine(S : String);
end;

type TStdError = class
private
   h : THandle;
public
   constructor Create;
   procedure WriteLine(S : String);
end;

function IsDebuggerPresent : Boolean;


implementation

uses winioctl;

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
var
   se : TStdError;
begin
   se := TStdError.Create;
   SetDebug(se.WriteLine);
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


end.
