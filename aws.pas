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
function IsAWS : Boolean;
function GetAWSVolumeType(DiskNumber : Integer) : String;
function GetAWSVolumeName(DiskNumber : Integer) : String;
procedure OnlineDisk(DiskNumber : Integer);

implementation

var
   VolumeType : TStringList;
   VolumeName : TStringList;

function GetAWSVolumeType(DiskNumber : Integer) : String;
var
   DiskNo : String;
begin
  if not Assigned(VolumeType) then
  begin
    FindAWSBlockDevices;
  end;
  DiskNo := IntToStr(DiskNumber);
  Result := VolumeType.Values[DiskNo];
end;

function GetAWSVolumeName(DiskNumber : Integer) : String;
var
   DiskNo : String;
begin
  if not Assigned(VolumeName) then
  begin
    FindAWSBlockDevices;
  end;
  DiskNo := IntToStr(DiskNumber);
  Result := VolumeName.Values[DiskNo];
end;

// Use WMI to try and work out if this is an AWS/Xen instance
function IsAWS : Boolean;
var
   FSWbemLocator : OLEVariant;
   FWMIService   : OLEVariant;
   FWbemObjectSet: OLEVariant;
   FWbemObject   : OLEVariant;
   oEnum         : IEnumvariant;
   iValue        : LongWord;
   Version       : String;
begin
    Result := False;
    FSWbemLocator := CreateOleObject('WbemScripting.SWbemLocator');
    FWMIService   := FSWbemLocator.ConnectServer('localhost', 'Root\cimv2', '', '');
    FWbemObjectSet:= FWMIService.ExecQuery('SELECT * FROM win32_bios','WQL');
    //get the enumerator
    oEnum         := IUnknown(FWbemObjectSet._NewEnum) as IEnumVariant;
    //traverse the data
    while oEnum.Next(1, FWbemObject, iValue) = 0 do
    begin
      if EndsWith(FWbemObject.SMBIOSBIOSVersion, 'amazon', version) then
      begin
        Result := true;
      end
    end
end;

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
   DiskNumber : String;
begin
  VolumeType := TStringList.Create;
  VolumeName := TStringList.Create;

  if IsAWS then
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
              DiskNumber := FWbemObject.DeviceId;
              Id := StrToIntDef(IdStr, -1);
              if Id >= 0 then
              begin
                // We got it at last
                if Id = 0 then
                begin
                   VolumeName.Values[DiskNumber] := '/dev/sda1';
                   VolumeType.Values[DiskNumber] := 'ROOT';
                end
                else if Id <= 25 then
                begin
                  VolumeName.Values[DiskNumber] := 'xvd' + Chr(Id + Ord('a'));
                  VolumeType.Values[DiskNumber] := 'EBS';
                end
                else if (Id >= 78) and (Id <= 89) then
                begin
                  VolumeName.Values[DiskNumber] :=  'xvdc' + Chr(id - 78 + Ord('a'));
                  VolumeType.Values[DiskNumber] := 'INSTANCE';
                end;
              end;
            end;

           // DiskNumber := FWbemObject.Number;
            Location.Free;

          end;
          FWbemObject:=Unassigned;
        end
    end
end;

procedure OnlineDisk(DiskNumber : Integer);
var
   FSWbemLocator : OLEVariant;
   FWMIService   : OLEVariant;
   FWbemObjectSet: OLEVariant;
   FWbemObject   : OLEVariant;
   oEnum         : IEnumvariant;
   iValue        : LongWord;
   Version       : String;
begin

    FSWbemLocator := CreateOleObject('WbemScripting.SWbemLocator');
    FWMIService   := FSWbemLocator.ConnectServer('localhost', 'Root\Microsoft\Windows\Storage', '', '');
    FWbemObjectSet:= FWMIService.ExecQuery('SELECT * FROM MSFT_Disk','WQL');
    //get the enumerator
    oEnum         := IUnknown(FWbemObjectSet._NewEnum) as IEnumVariant;
    //traverse the data
    while oEnum.Next(1, FWbemObject, iValue) = 0 do
    begin
      if StrToInt(FWbemObject.Number) = DiskNumber then
      begin
        FWbemObject.Online();
        FWbemObject.SetAttributes(False); // Set the ReadOnly attribute
      end
    end
end;

end.

