program dd;
{$APPTYPE CONSOLE}
{%File 'ddchanges.txt'}

uses
  SysUtils,
  Windows,
  Classes,
  Filectrl,
  Native in 'Native.pas',
  volume in 'volume.pas',
  WinBinFile in 'WinBinFile.pas',
  WinIOCTL in 'WinIOCTL.pas',
  studio_tools in 'studio\studio_tools.pas',
  debug in 'studio\debug.pas',
  md5 in 'studio\md5\md5.pas',
  persrc in 'studio\persrc.pas',
  MT19937 in 'studio\random\MT19937.pas';

var
   Version       : TOSVersionInfo;
   VersionString : String;
   OSis95        : Boolean;
   Exitcode      : Integer;

   // command line parameters
   Action       : String;
   Count        : Int64;
   InFile       : String;
   OutFile      : String;
   Seek         : Int64;
   Skip         : Int64;
   BlockSize    : Int64;
   BlockUnit    : String;
   Progress     : Boolean;
   CheckSize    : Boolean;
   Unmounts     : TStringList;
   DeviceFilter : String;
   Onocreat     : Boolean;
   Onotrunc     : Boolean;
   Oexcl        : Boolean;

   idod_BlockSize : String;
   idod_size : Boolean;

{
    dd for windows
    Copyright (C) 2003 John Newbigin <jn@it.swin.edu.au>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
}

function GetBlockSize(S : String) : Int64; forward;

type TDDProgress = class
public
   BlockSize : Int64;
   Count     : Int64;
   BlockUnit : String;
   BlockFactor : Int64;
   procedure SetUnit(BlockUnit : String);
   function DDProgress(Progress : Int64; Error : DWORD) : Boolean;
end;

function TDDProgress.DDProgress(Progress : Int64; Error : DWORD) : Boolean;
var
   Number   : String;
   S        : String;
   Len      : Integer;
   i        : Integer;
   PerCent  : Integer;
   P        : String;
begin
   Result := False;
   if Count > 0 then
   begin
      // we know how many blocks so we can do a %
      PerCent := Progress * 100 div (Count * BlockSize);
      P := ' ' + IntToStr(PerCent) + '%';
   end;
//   else
   begin
      Progress := Progress div BlockFactor;
      Number := IntToStr(Progress);
      Len := Length(Number);
      for i := 1 to Len do
      begin
         S := S + Number[i];
         if (i < Len) and ((Len - i) mod 3 = 0) then
         begin
            S := S + ',';
         end;
      end;

      S := S + BlockUnit;

         stderr.write(#13 + S + P + ' ');
   end;
end;

procedure TDDProgress.SetUnit(BlockUnit : String);
begin
   self.BlockUnit := BlockUnit;
   BlockFactor := GetBlockSize('1' + BlockUnit);
end;

procedure PrintUsage;
begin
   Log('dd [bs=SIZE] [count=BLOCKS] [if=FILE] [of=FILE] [seek=BLOCKS] [skip=BLOCKS] [--size] [--list] [--progress]');
   Log('SIZE and BLOCKS may have one of the following suffix:');
   Log(' k = 1024');
   Log(' M = 1048576');
   Log(' G = 1073741824');
   Log('default block size (bs) is 512 bytes');
   Log('skip specifies the starting offset of the input file (if)');
   Log('seek specifies the starting offset of the output file (of)');
end;

procedure GetListOfMountPoints(List : TStringList);
   procedure EnumerateVolumeMountPoints(Volume : String);
   var
      Buffer : String;
      vh : THandle;
   begin
      SetLength(Buffer, 1024);
      vh := JFindFirstVolumeMountPoint(PChar(Volume), PChar(Buffer), Length(Buffer));
      while vh <> INVALID_HANDLE_VALUE do
      begin
         SetLength(Buffer, strlen(PChar(Buffer)));
         //Log('Mount point = ' + Buffer);

         Buffer := Volume + Buffer;
         List.Add(Buffer);

         SetLength(Buffer, 1024);
         if not JFindNextVolumeMountPoint(vh, PChar(Buffer), Length(Buffer)) then
         begin
            JFindVolumeMountPointClose(vh);
            vh := INVALID_HANDLE_VALUE;
         end;
      end;
      //Log('No more mount points');
   end;

var
   Buffer : String;
   h : THandle;
begin
   LoadVolume;

   // Enumerate the volumes
   SetLength(Buffer, 1024);

   h := JFindFirstVolume(PChar(Buffer), Length(Buffer));
   while h <> INVALID_HANDLE_VALUE do
   begin
      SetLength(Buffer, strlen(PChar(Buffer)));
      //Log('FindVolume' + Buffer);
      EnumerateVolumeMountPoints(Buffer);

      SetLength(Buffer, 1024);
      if not JFindNextVolume(h, PChar(Buffer), Length(Buffer)) then
      begin
         JFindVolumeClose(h);
         h := INVALID_HANDLE_VALUE;
      end;
   end;
end;

function FilterMatch(Device : String; Media : Integer; Filter : String) : Boolean;
var
   Base : String;
begin
   Result := false;

   if Filter = 'fixed' then
   begin
      if Media = Media_Type_FixedMedia then
      begin
         Filter := 'disk';
      end;
   end
   else if Filter = 'removable' then
   begin
      if Media <> Media_Type_FixedMedia then
      begin
         Filter := 'disk';
      end;
   end;

   if Filter = 'disk' then
   begin
      if EndsWith(Device, 'Partition0', Base) then
      begin
         Result := True;
      end;
   end
   else if Filter = 'partition' then
   begin
      if not EndsWith(Device, 'Partition0', Base) then
      begin
         Result := True;
      end;
   end;
end;

function CheckFilter(Device : String; Filter : String) : Boolean;
var
   h        : THandle;
   Geometry : TDISK_GEOMETRY;
   Len      : DWORD;
   Value    : String;

   Path     : String;
begin

// what about file... Make sure the path exists?
   if Filter = 'file' then
   begin
      Path := ExpandFileName(Device);
      Path := ExtractFilePath(Path);

      if DirectoryExists(Path) then
      begin
         //Log('Output path is ' + path);
         Result := True;
         exit;
      end
      else
      begin
         Log('Output path ' + Path + ' does not exist');
      end;
   end;

   if StartsWith(Device, '\\?\', Value) then
   begin
      // do a native open
      Value := '\' + Value;
      //Log('ntopen ' + Value);
      h := NTCreateFile(PChar(Value), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_FLAG_RANDOM_ACCESS, 0);
   end
   else
   begin
      h := CreateFile(PChar(Device), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_FLAG_RANDOM_ACCESS, 0);
   end;

   Result := False;
   if h <> INVALID_HANDLE_VALUE then
   begin
      try
         // get the geometry...
         if DeviceIoControl(h, CtlCode(FILE_DEVICE_DISK, 0, METHOD_BUFFERED, FILE_ANY_ACCESS), nil, 0, Pointer(@Geometry), Sizeof(Geometry), Len, nil) then
         begin
            Result := FilterMatch(Device, Geometry.MediaType, Filter);
         end;
      finally
         CloseHandle(h);
      end;
   end;
end;

procedure PrintNT4BlockDevices(Filter : String);
var
   Devices : TStringList;
   i : Integer;
   Number : String;
   Harddisks : TStringList;

   DriveNo    : Integer;
   PartNo     : Integer;
   DeviceName : String;
   ErrorNo    : DWORD;
   Geometry   : TDISK_GEOMETRY;
   Len        : DWORD;
   Description : String;
   VolumeLink : String;
   Size       : Int64;

   function TestDevice(DeviceName : String; var Description : String) : Boolean;
   var
      h : THandle;
   begin
      Result := False;
      Description := '';
      Size := 0;

      h := NTCreateFile(PChar(DeviceName), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_FLAG_RANDOM_ACCESS, 0);

      if h <> INVALID_HANDLE_VALUE then
      begin
         try
            //Log('Opened ' + DeviceName);
            Result := True;

            // get the geometry...
            if DeviceIoControl(h, CtlCode(FILE_DEVICE_DISK, 0, METHOD_BUFFERED, FILE_ANY_ACCESS), nil, 0, Pointer(@Geometry), Sizeof(Geometry), Len, nil) then
            begin
               Description := MediaDescription(Geometry.MediaType) + '. Block size = ' + IntToStr(Geometry.BytesPerSector);
//               Size.QuadPart := Geometry.Cylinders.QuadPart * Geometry.TracksPerCylinder * Geometry.SectorsPerTrack * Geometry.BytesPerSector;
//               Log('size = ' + IntToStr(Size.QuadPart));

            end
            else
            begin
               Geometry.MediaType := Media_Type_Unknown;
               //ShowError('reading geometry');
            end;
            if Filter <> '' then
            begin
               Result := FilterMatch(DeviceName, Geometry.MediaType, Filter);
            end;
            Size := GetSize(h);
         finally
            CloseHandle(h);
         end;
      end
      else
      begin
         ErrorNo := Native.GetLastError;
         if ErrorNo = ERROR_FILE_NOT_FOUND then
         begin
            // does not matter
         end
         else if ErrorNo = ERROR_PATH_NOT_FOUND then
         begin
            // does not matter
         end
         else if ErrorNo = 5 then
         begin
//               MessageDlg('This program requires Administrator privilages to run', mtError, [mbOK], 0);
         end
         else if ErrorNo = ERROR_SHARING_VIOLATION then
         begin
            // in use (probably mounted)...
            if Filter = '' then
            begin
               Result := True;
            end;
         end
         else
         begin
            ShowError('opening device');
         end;
      end;
   end;
begin
   Devices := TStringList.Create;
   Devices.Sorted := True;
   Harddisks := TStringList.Create;
   Harddisks.Sorted := True;
   try

      NativeDir('\Device', Devices);

      for i := 0 to Devices.Count - 1 do
      begin
         DeviceName := '';

         if StartsWith(Devices[i], 'CdRom', Number) then
         begin
            DriveNo := StrToIntDef(Number, -1);
            if DriveNo >= 0 then
            begin
               DeviceName := '\Device\CdRom' + IntToStr(DriveNo);
            end;
         end
         else if StartsWith(Devices[i], 'Floppy', Number) then
         begin
            DriveNo := StrToIntDef(Number, -1);
            if DriveNo >= 0 then
            begin
               DeviceName := '\Device\Floppy' + IntToStr(DriveNo);
            end;
         end
         else if StartsWith(Devices[i], 'Harddisk', Number) then
         begin
            DriveNo := StrToIntDef(Number, -1);
            if DriveNo >= 0 then
            begin
               // scan the partitions...
               Harddisks.Add('\Device\Harddisk' + IntToStr(DriveNo));
            end;
         end;

         if Length(DeviceName) > 0 then
         begin
            if TestDevice(DeviceName, Description) then
            begin
               Log('\\?' + DeviceName);
               VolumeLink := NativeReadLink(DeviceName);
               if Length(VolumeLink) > 0 then
               begin
                  Log('  link to \\?' + VolumeLink);
               end;
               if Length(Description) > 0 then
               begin
                  Log('  ' + Description);
               end;
               if Size > 0 then
               begin
                  Log('  size is ' + IntToStr(Size) + ' bytes');
               end;
            end
         end;
      end;

      // do the hard disk partitions...
      for DriveNo := 0 to Harddisks.Count - 1 do
      begin
         Devices.Clear;
         NativeDir(Harddisks[DriveNo], Devices);
         for i := 0 to Devices.Count - 1 do
         begin
            if StartsWith(Devices[i], 'Partition', Number) then
            begin
               PartNo := StrToIntDef(Number, -1);
               if PartNo >= 0 then
               begin
                  DeviceName := Harddisks[DriveNo] + '\Partition' + IntToStr(PartNo);
                  if TestDevice(DeviceName, Description) then
                  begin
                     Log('\\?' + DeviceName);
                     VolumeLink := NativeReadLink(DeviceName);
                     if Length(VolumeLink) > 0 then
                     begin
                        Log('  link to \\?' + VolumeLink);
                     end;
                     if Length(Description) > 0 then
                     begin
                        Log('  ' + Description);
                     end;
                     if Size > 0 then
                     begin
                        Log('  size is ' + IntToStr(Size) + ' bytes');
                     end;
                  end
               end;
            end
         end;
      end;
   finally
      Devices.Free;
      Harddisks.Free;
   end;

   if Filter = '' then
   begin
      Log('');
      Log('Virtual input devices');
      Log(' /dev/zero   (null data)');
      Log(' /dev/random (pseudo-random data)');
      Log(' -           (standard input)');
      Log('');
      Log('Virtual output devices');
      Log(' -           (standard output)');
      Log(' /dev/null   (discard the data)');
   end;
end;

procedure PrintBlockDevices(Filter : String);
var
   h : THandle;
   VolumeName : String;
   MountPoints : TStringList;
   MountVolumes : TStringList;
   VolumeLink : String;
   i : Integer;
   Drive : Char;
   DriveString : String;
   Buffer : String;
   VolumeLetter : array ['a'..'z'] of String;
   MountCount : Integer;
begin
   // search for block devices...
   if OSis95 then
   begin
      Log('--list is not available for Win95');
   end
   else
   begin
      try
         if Filter = '' then
         begin
            Log('Win32 Available Volume Information');
            LoadVolume;
            MountPoints := TStringList.Create;
            MountVolumes := TStringList.Create;
            GetListOfMountPoints(MountPoints);
            for i := 0 to MountPoints.Count - 1 do
            begin
               //Log('mp=' + MountPoints[i]);
               SetLength(Buffer, 1024);
               if JGetVolumeNameForVolumeMountPoint(PChar(MountPoints[i]), PChar(Buffer), Length(Buffer)) then
               begin
                  SetLength(Buffer, strlen(PChar(Buffer)));
                  MountVolumes.Add(Buffer);
                  //Log('   ' + Buffer);
               end
               else
               begin
                  MountVolumes.Add('');
               end;
            end;

            // volumes only work on 2k+
            // for NT4 we need to search physicaldrive stuff.

            for Drive := 'a' to 'z' do
            begin
               DriveString := Drive + ':\';

               SetLength(Buffer, 1024);
               if JGetVolumeNameForVolumeMountPoint(PChar(DriveString), PChar(Buffer), Length(Buffer)) then
               begin
                  SetLength(Buffer, strlen(PChar(Buffer)));
                  if Length(Buffer) > 0 then
                  begin
      //               Buffer := Copy(Buffer, 12, Length(Buffer) - 13);
                     VolumeLetter[Drive] := Buffer;
      //               Log(DriveString + ' = ' + Buffer);
                  end;
               end;
            end;



            SetLength(VolumeName, 1024);
            h := JFindFirstVolume(PChar(VolumeName), Length(VolumeName));
            if h <> INVALID_HANDLE_VALUE then
            begin
               while True do
               begin
                  SetLength(VolumeName, strlen(PChar(VolumeName)));
                  Log('\\.\' + Copy(VolumeName, 5, Length(VolumeName)));
                  // see where this symlink points...
                  VolumeLink := NativeReadLink('\??\' + Copy(VolumeName, 5, Length(VolumeName) - 5));
                  if Length(VolumeLink) > 0 then
                  begin
                     Log('  link to \\?' + VolumeLink);
                  end;
                  Log('  ' + GetDriveTypeDescription(GetDriveType(PChar(VolumeName))));

                  MountCount := 0;
                  // see if this matches a drive letter...
                  for Drive := 'a' to 'z' do
                  begin
                     if VolumeLetter[Drive] = VolumeName then
                     begin
                        Log('  Mounted on \\.\' + Drive + ':');
                        MountCount := MountCount + 1;
                     end;
                  end;
                  // see if this matches a mount point...
                  for i := 0 to MountPoints.Count - 1 do
                  begin
                     if MountVolumes[i] = VolumeName then
                     begin
                        Log('  Mounted on ' + MountPoints[i]);
                        MountCount := MountCount + 1;
                     end;
                  end;

                  if MountCount = 0 then
                  begin
                     Log('  Not mounted');
                  end;

                  Log('');

                  SetLength(VolumeName, 1024);
                  if not JFindNextVolume(h, PChar(VolumeName), Length(VolumeName)) then break;
               end;
               JFindVolumeClose(h);
            end;
         end;
      except
         on E : Exception do
         begin
            // Volumes are not supported under NT4
         end;
      end;
      Log('');
      Log('NT Block Device Objects');
      PrintNT4BlockDevices(Filter);
   end;

end;

function GetBlockSize(S : String) : Int64;
var
   Suffix : String;
begin
   // see if there is a suffix to the block size
   // c = 1
   // w = 2
   // d = 4
   // q = 8
   // k = 1024 kilo
   // M = 1048576 Mega
   // G = 1073741824 Giga
   // T = 1099511627776 Tera
   // P = 1125899906842624 Peta
   // E = 1152921504606846976 Exa
   // Z = 1180591620717411303424 Zetta
   // Y = 1208925819614629174706176 Yotta

   while Length(S) > 0 do
   begin
      if S[Length(S)] in ['a'..'z', 'A'..'Z'] then
      begin
         Suffix := S[Length(S)] + Suffix;
         S := Copy(S, 1, Length(S) - 1);
      end
      else
      begin
         break;
      end;
   end;
   //Log(' n = ' + S);
   Result := StrToInt64Def(S, 0);
   //Log(' s = ' + Suffix);
   if (Suffix = 'c') or (Suffix = '') then
   begin
      // no multipier
   end
   else if Suffix = 'w' then
   begin
      Result := Result * 2;
   end
   else if Suffix = 'd' then
   begin
      Result := Result * 4;
   end
   else if Suffix = 'q' then
   begin
      Result := Result * 8;
   end
   else if Suffix = 'k' then
   begin
      Result := Result * 1024;
   end
   else if Suffix = 'M' then
   begin
      Result := Result * 1048576;
   end
   else if Suffix = 'G' then
   begin
      Result := Result * 1073741824;
   end
   else
   begin
      Log('Unknown suffix ' + Suffix);
      Exitcode := 1;
      Result := 0;
   end
end;

function GetBlockSuffix(S : String) : String;
var
   Suffix : String;
begin
   while Length(S) > 0 do
   begin
      if S[Length(S)] in ['a'..'z', 'A'..'Z'] then
      begin
         Suffix := S[Length(S)] + Suffix;
         S := Copy(S, 1, Length(S) - 1);
      end
      else
      begin
         break;
      end;
   end;
   Result := Suffix;
end;

function VerifyDiskContaining(Drive : String) : String;
var
   DriveString : String;
   Buffer      : String;
   DeviceName  : String;
   VolumeLink  : String;
   Id          : String;
   Devices     : TStringList;
   HardDisks   : TStringList;
   i           : Integer;
   DriveNo     : Integer;
   PartNo      : Integer;
   DeviceName2 : String;
   WantedDisk  : Integer;
begin
   LoadVolume;
   Result := '';

   // step 1, make a list of drive letters -> devices
   // if the requested drive only has one segement after \\?\device\ then we can just use that
   DriveString := Drive + '\';

   SetLength(Buffer, 1024);
   if JGetVolumeNameForVolumeMountPoint(PChar(DriveString), PChar(Buffer), Length(Buffer)) then
   begin
      SetLength(Buffer, strlen(PChar(Buffer)));
      if Length(Buffer) > 0 then
      begin
         DeviceName := Buffer;
      end;
   end;

   if Length(DeviceName) > 0 then
   begin
      VolumeLink := NativeReadLink('\??\' + Copy(DeviceName, 5, Length(DeviceName) - 5));
   end;

   if Length(VolumeLink) > 0 then
   begin
      DeviceName := '\\?' + VolumeLink;
      Log('Device ' + Drive + ' is a link to ' + DeviceName);
   end
   else
   begin
      Log('Device ' + Drive + ' could not be found');
      exit;
   end;

   if StartsWith(DeviceName, '\\?\Device\Floppy', Id) then
   begin
      idod_BlockSize := '18k'; // good 'round' number for 1.44Meg floppy
      idod_Size := False;
      Result := DeviceName;
      exit;
   end
   else if StartsWith(DeviceName, '\\?\Device\CdRom', Id) then
   begin
      idod_BlockSize := '2k';
      idod_Size := False;
      Result := DeviceName;
      exit;
   end;


   // else step 2, make sure that there is only one partition on that device
   // if there is only one, returun the device (partition0)

   // we must do an NT4 scan of hard disks to find what links to the same object
   Devices := TStringList.Create;
   Devices.Sorted := True;
   Harddisks := TStringList.Create;
   Harddisks.Sorted := True;

   try
      NativeDir('\Device', Devices);

      for i := 0 to Devices.Count - 1 do
      begin
         if StartsWith(Devices[i], 'Harddisk', Id) then
         begin
            DriveNo := StrToIntDef(Id, -1);
            if DriveNo >= 0 then
            begin
               // scan the partitions...
               HardDisks.AddObject('\Device\Harddisk' + IntToStr(DriveNo), TObject(0));
            end;
         end;
      end;

      WantedDisk := -1;

      for DriveNo := 0 to Harddisks.Count - 1 do
      begin
         Devices.Clear;
         NativeDir(Harddisks[DriveNo], Devices);
         for i := 0 to Devices.Count - 1 do
         begin
            if StartsWith(Devices[i], 'Partition', Id) then
            begin
               PartNo := StrToIntDef(Id, -1);
               if PartNo >= 0 then
               begin
                  DeviceName2 := Harddisks[DriveNo] + '\Partition' + IntToStr(PartNo);
                  //Log('*' + DeviceName2);
                  HardDisks.Objects[DriveNo] := TObject(Integer(HardDisks.Objects[DriveNo]) + 1);


                  VolumeLink := '\\?' + NativeReadLink(DeviceName2);
                  DeviceName2 := '\\?' + DeviceName2;

                  if DeviceName = VolumeLink then
                  begin
                     Log(DeviceName + ' is a partition on ' + Harddisks[DriveNo]);

                     WantedDisk := DriveNo;
                  end;
               end;
            end
         end;
      end;

      if WantedDisk >= 0 then
      begin
         if Integer(HardDisks.Objects[WantedDisk]) = 2 then
         begin
            Result := '\\?' + Harddisks[WantedDisk] + '\Partition0';
            idod_BlockSize := '1M';
            idod_Size := True;
            exit;
         end
         else
         begin
            Log('Multiple partitions were found on ' + Harddisks[WantedDisk] + '.');
            Log('Use ''if=\\?' + Harddisks[WantedDisk] + '\Partition0'' instead');
         end;
      end
      else
      begin
         Log('No match could be found for ' + Drive);
      end;

   finally
      HardDisks.Free;
      Devices.Free;
   end;

   Log('');
end;

var
   i : Integer;
   j : Integer;
   Value : String;
   ProgressCallback : TDDProgress;
   ExeName     : String;
   Parameters  : TStringList;
   Chopper     : TStringList;
begin
   Exitcode := 0;
   //UseWriteln;
   UseStdError;
   Log('rawwrite dd for windows version ' + AppVersion + '.');
   Log('Written by John Newbigin <jn@it.swin.edu.au>');
   Log('This program is covered by terms of the GPL Version 2.');
   Log('');

   Parameters := TStringList.Create;

   ExeName := LowerCase(ExtractFileName(ParamStr(0)));
   if StartsWith(ExeName, 'dd-', Value) then
   begin
      if EndsWith(Value, '.exe', Value) then
      begin
         //Log('Filter is ' + Value);
         Parameters.Add('--filter=' + Value);
      end;
      // we must have a default filter

   end;
   
   SetErrorMode(SEM_FAILCRITICALERRORS);

   // what OS
   Version.dwOSVersionInfoSize := Sizeof(Version);
   if GetVersionEx(Version) then
   begin
      case Version.dwPlatformId of
         VER_PLATFORM_WIN32s        : VersionString := 'WIN32s';
         VER_PLATFORM_WIN32_WINDOWS : VersionString := 'Windows 95';
         VER_PLATFORM_WIN32_NT      : VersionString := 'Windows NT';
      else
         VersionString := 'Unknown OS';
      end;
      VersionString := VersionString + ' ' + IntToStr(Version.dwMajorVersion) +
                                       '.' + IntToStr(Version.dwMinorVersion) +
                                       ' build number ' + IntToStr(Version.dwBuildNumber);
//      StatusBar1.Panels[2].Text := VersionString;
      if Version.dwPlatformId = VER_PLATFORM_WIN32_WINDOWS then
      begin
         OSis95 := True;
      end
      else
      begin
         OSis95 := False;
      end;
   end
   else
   begin
      Log('Could not get Version info!');
   end;

   // check the command line parameters
   Action    := 'dd';
   Count     := -1;
   BlockSize := 512;
   BlockUnit := '';
   Seek      := 0;
   Skip      := 0;
   Progress  := False;
   CheckSize := False;
   Unmounts  := TStringList.Create;
   InFile    := '-';
   OutFile   := '-';


   for i := 1 to ParamCount do
   begin
      Parameters.Add(ParamStr(i));
   end;

   // count=
   // if=
   // of=
   // seek=
   // skip=
   // bs=
   // --list
   for i := 0 to Parameters.Count - 1 do
   begin
      if Parameters[i] = '--list' then
      begin
         Action := 'list';
      end
      else if Parameters[i] = '--progress' then
      begin
         Progress := True;
      end
      else if Parameters[i] = '--size' then
      begin
         CheckSize := True;
      end
      else if StartsWith(Parameters[i], 'count=', Value) then
      begin
         Count := GetBlockSize(Value);
      end
      else if StartsWith(Parameters[i], 'if=', Value) then
      begin
         InFile := Value;
      end
      else if StartsWith(Parameters[i], 'of=', Value) then
      begin
         OutFile := Value;
      end
      else if StartsWith(Parameters[i], 'id=', Value) then
      begin
         InFile := VerifyDiskContaining(Value);
         BlockSize := GetBlockSize(idod_BlockSize);
         BlockUnit := GetBlockSuffix(idod_BlockSize);
         Progress := True;
         CheckSize := idod_size;
      end
      else if StartsWith(Parameters[i], 'od=', Value) then
      begin
         OutFile := VerifyDiskContaining(Value);
         BlockSize := GetBlockSize(idod_BlockSize);
         BlockUnit := GetBlockSuffix(idod_BlockSize);
         Progress := True;
      end
      else if StartsWith(Parameters[i], 'seek=', Value) then
      begin
         Seek := GetBlockSize(Value);
      end
      else if StartsWith(Parameters[i], 'skip=', Value) then
      begin
         Skip := GetBlockSize(Value);
      end
      else if StartsWith(Parameters[i], 'bs=', Value) then
      begin
         BlockSize := GetBlockSize(Value);
         BlockUnit := GetBlockSuffix(Value);
      end
      else if StartsWith(Parameters[i], 'conv=', Value) then
      begin
         // chop up at ,
         Chopper := TStringList.Create;
         Chopper.CommaText := Value;
         for j := 0 to Chopper.Count - 1 do
         begin
            Log(Chopper[j]);
         end;
         Chopper.Free;
      end
      else if StartsWith(Parameters[i], '--filter=', Value) then
      begin
         if Value = 'removable' then
         begin
            DeviceFilter := Value;
         end
         else if Value = 'fixed' then
         begin
            DeviceFilter := Value;
         end
         else if Value = 'disk' then
         begin
            DeviceFilter := Value;
         end
         else if Value = 'partition' then
         begin
            DeviceFilter := Value;
         end
         else if Value = 'file' then
         begin
            DeviceFilter := Value;
         end
         else
         begin
            Log('Invalid filter');
            Action := 'usage';
            Exitcode := 1;
         end;
      end
      else if StartsWith(Parameters[i], '--unmount=', Value) then
      begin
         // Not ready yet...
         //Unmounts.Add(Value);
      end
      else if (Parameters[i] = '--help') or (Parameters[i] = '-h') then
      begin
         Action := 'usage';
      end
      else if (Parameters[i] = '--version') or (Parameters[i] = '-V') then
      begin
         Action := '';
      end
      else
      begin
         Log('Unknown command ' +  Parameters[i]);
         Action := 'usage';
         Exitcode := 1;
      end;
   end;

   if (Action = 'dd') and (Length(InFile) = 0) then
   begin
      if Unmounts.Count > 0 then
      begin
         Action := 'unmount';
      end
      else
      begin
         Action := 'usage';
      end;
   end;

   if (Action = 'dd') or (Action = 'unmount') then
   begin
      for i := 0 to Unmounts.Count - 1 do
      begin
         LoadVolume;
         JDeleteVolumeMountPoint(PChar(Unmounts[i]));
      end;
   end;

//   Log('Action is ' + Action);
   if Action = 'usage' then
   begin
      PrintUsage;
   end
   else if Action = 'list' then
   begin
      PrintBlockDevices(DeviceFilter);
   end
   else if Action = 'dd' then
   begin
      if DeviceFilter <> '' then
      begin
         // filter the output file...
         if not CheckFilter(OutFile, DeviceFilter) then
         begin
            Log('Output file does not match device filter ''' + DeviceFilter + '''');
            Log('dd will not continue');
            BlockSize := 0; // trigger dd to not run
         end;
      end;
      Count := Count;
      Skip  := Skip * BlockSize;
      Seek  := Seek * Blocksize;
      if BlockSize > 0 then
      begin
         if Progress then
         begin
            ProgressCallback := TDDProgress.Create;
            ProgressCallback.BlockSize := BlockSize;
            ProgressCallback.Count := Count;
            ProgressCallback.SetUnit(BlockUnit);
            DoDD(InFile, OutFile, BlockSize, Count, Skip, Seek, Onotrunc, CheckSize, ProgressCallback.DDProgress);
            ProgressCallback.Free;
         end
         else
         begin
            DoDD(InFile, OutFile, BlockSize, Count, Skip, Seek, Onotrunc, CheckSize, nil);
         end;
      end
      else
      begin
         Log('Invalid block size');
      end;
   end
   else if Action = 'unmount' then
   begin
      // dummy target
   end
   else if Action = '' then
   begin
      // nothing to do
   end
   else
   begin
      Log('Unknown action ' + Action);
   end;
   if IsDebuggerPresent then
   begin
      Log('Press enter to close');
      readln;
   end;
   Halt(Exitcode);
end.
