unit aws;

{$mode delphi}

interface

uses
  Classes,
  studio_tools,
  SysUtils,
  Variants,
  ComObj,
  ActiveX;

procedure FindAWSBlockDevices;

implementation

procedure FindAWSBlockDevices;
var
   FSWbemLocator : OLEVariant;
   FWMIService   : OLEVariant;
   FWbemObjectSet: OLEVariant;
   FWbemObject   : OLEVariant;
   oEnum         : IEnumvariant;
   iValue        : LongWord;

   Location : TStringList;
   Target   : String;
   IdStr      : String;
   Id         : Integer;
   DiskNumber : Integer;
   DiskType : String;
   DiskName : String;
begin
  FSWbemLocator := CreateOleObject('WbemScripting.SWbemLocator');
  FWMIService   := FSWbemLocator.ConnectServer('localhost', 'Root\Microsoft\Windows\Storage', '', '');
  FWbemObjectSet:= FWMIService.ExecQuery('SELECT * FROM MSFT_PhysicalDisk','WQL');
    //get the enumerator
    oEnum         := IUnknown(FWbemObjectSet._NewEnum) as IEnumVariant;
    //traverse the data
    while oEnum.Next(1, FWbemObject, iValue) = 0 do
    begin
      if (FWbemObject.BusType = 1) {SCSI} and (FWbemObject.Manufacturer = 'AWS') then
      begin
        Location := TStringList.Create;
        Location.StrictDelimiter := True;
        Location.Delimiter := ':';
        Location.DelimitedText := FWbemObject.PhysicalLocation;
        Target := Trim(Location[3]);
        if StartsWith(Target, 'Target ', IdStr) then
        begin
          DiskNumber := StrToInt(FWbemObject.DeviceId);
          Id := StrToIntDef(IdStr, -1);
          if Id >= 0 then
          begin
            DiskType := 'UNKNOWN';
            // We got it at last
            if Id = 0 then
            begin
               DiskName := '/dev/sda1';
               DiskType := 'ROOT';
            end
            else if Id <= 25 then
            begin
              DiskName := 'xvd' + Chr(Id + Ord('a'));
              DiskType := 'EBS';
            end
            else if (Id >= 78) and (Id <= 89) then
            begin
              DiskName :=  'xvdc' + Chr(id - 78 + Ord('a'));
              DiskType := 'INSTANCE';
            end;
          end;
          Writeln(IntToStr(DiskNumber) + ' ' + IdStr + ' ' + DiskName + ' ' + DiskType);
        end;

       // DiskNumber := FWbemObject.Number;
        Location.Free;

      end;
      FWbemObject:=Unassigned;
    end;
end;

end.

