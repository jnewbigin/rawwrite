unit unitResourceDialogs;

interface

uses Windows, Classes, SysUtils, unitResourceDetails;

type

TDialogResourceDetails = class (TResourceDetails)
public
  class function GetBaseType : string; override;
  procedure InitNew; override;
end;

implementation

{ TDialogResourceDetails }

class function TDialogResourceDetails.GetBaseType: string;
begin
  result := IntToStr (Integer (RT_DIALOG));
end;

procedure TDialogResourceDetails.InitNew;
var
  template : TDlgTemplate;
  w : Word;
  faceName : WideString;

begin
  template.Style := DS_MODALFRAME or WS_POPUP or WS_CAPTION or WS_SYSMENU or DS_SETFONT or WS_VISIBLE;
  template.dwExtendedStyle := 0;
  template.cdit := 0;
  template.x := 0;
  template.y := 0;
  template.cx := 186;   // Defaults from VC6
  template.cy := 95;

  data.Write (template, SizeOf (template));

  w := 0;
  data.Write (w, SizeOf (w));   // Menu sz or id
  data.write (w, SizeOf (w));   // Class sz or id
  data.Write (w, SizeOf (w));   // Title sz or id

  w := 8;
  data.write (w, SizeOf (w));   // Point size

  faceName := 'MS Shell Dlg';
  data.Write (PWideChar (faceName)^, (Length (faceName) + 1) * SizeOf (WideChar))
end;

initialization
  RegisterResourceDetails (TDialogResourceDetails);
finalization
  UnregisterResourceDetails (TDialogResourceDetails);
end.
