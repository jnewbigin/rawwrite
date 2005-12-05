unit debug;

{$IFDEF FPC}
{$MODE Delphi}
{$ENDIF}

// $Header: /home/cso/jnewbigin/cvsroot/rawwrite/studio/debug.pas,v 1.1 2004/12/30 13:50:08 jnewbigin Exp $

interface

procedure Log(S : String);
type DebugEvent = procedure (S : String) of object;
procedure SetDebug(d : DebugEvent);
procedure UseWriteln;

type TWriteLine = class
public
   procedure WriteLine(S : String);
end;

implementation

var
   fOnDebug : DebugEvent;

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
   Writeln(S);
{$ENDIF}
end;

procedure UseWriteln;
var
   wl : TWriteLine;
begin
   wl := TWriteLine.Create;
   SetDebug(wl.WriteLine);
end;

end.
