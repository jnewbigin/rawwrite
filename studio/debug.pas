unit debug;

// $Header: /home/itig/cvsroot/scsi/debug.pas,v 1.2 2002/04/16 06:37:18 jn Exp $

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
   Writeln(S);
end;

procedure UseWriteln;
var
   wl : TWriteLine;
begin
   wl := TWriteLine.Create;
   SetDebug(wl.WriteLine);
end;

end.
