program dd;
{$APPTYPE CONSOLE}
uses
  SysUtils,
  Windows,
  Classes,
  Native in 'Native.pas',
  volume in 'volume.pas',
  WinBinFile in 'WinBinFile.pas',
  WinIOCTL in 'WinIOCTL.pas',
  studio_tools in 'studio\studio_tools.pas',
  debug in 'studio\debug.pas';

var
   Version : TOSVersionInfo;
   VersionString : String;
   OSis95 : Boolean;

   // command line parameters
   Action      : String;
   Count       : Int64;
   InFile      : String;
   OutFile     : String;
   Seek        : Int64;
   Skip        : Int64;
   BlockSize   : Int64;

//const AppVersion = '0.2';
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

{procedure Debug(S : String);
begin
   writeln(S);
end;}

{procedure ShowError(Action : String);
begin
   Debug('Error ' + Action + ': ' + IntToStr(Windows.GetLastError) + ' ' + SysErrorMessage(Windows.GetLastError));
end;}

procedure PrintUsage;
begin
   Log('dd [bs=SIZE] [count=BLOCKS] [if=FILE] [of=FILE] [seek=BLOCKS] [skip=BLOCKS] [--list]');
   Log('SIZE may have one of the following suffix:');
   Log(' k = 1024');
   Log(' M = 1048576');
   Log(' G = 1073741824');
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

procedure PrintNT4BlockDevices;
var
   DriveNo    : Integer;
   PartNo     : Integer;
   DeviceName : String;
   Done       : Boolean;
   ErrorNo    : DWORD;
   Geometry   : TDISK_GEOMETRY;
   Len        : DWORD;
   Description : String;

   function TestDevice(DeviceName : String; var Description : String) : Boolean;
   var
      h : THandle;
   begin
      Result := False;
      Description := '';

      h := NTCreateFile(PChar(DeviceName), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_FLAG_RANDOM_ACCESS, 0);

      if h <> INVALID_HANDLE_VALUE then
      begin
         try
            //Log('Opened ' + DeviceName);
            Result := True;

            // get the geometry...
            if DeviceIoControl(h, CtlCode(FILE_DEVICE_DISK, 0, METHOD_BUFFERED, FILE_ANY_ACCESS), nil, 0, Pointer(@Geometry), Sizeof(Geometry), Len, nil) then
            begin
               //Log('Block size = ' + IntToStr(Geometry.BytesPerSector));
               //Log('Media type = ' + MediaDescription(Geometry.MediaType));
               Description := MediaDescription(Geometry.MediaType) + '. Block size = ' + IntToStr(Geometry.BytesPerSector);
            end
            else
            begin
               //ShowError('reading geometry');
            end;
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
            Result := True;
         end
         else
         begin
            ShowError('opening device');
         end;
      end;
   end;
begin
   DriveNo := 0;

   Done := False;

   while not Done do
   begin
      PartNo := 0;

      while True do
      begin
         DeviceName := '\Device\Harddisk' + IntToStr(DriveNo) + '\Partition' + IntToStr(PartNo);
         if TestDevice(DeviceName, Description) then
         begin
            Log('\\?' + DeviceName);
            PartNo := PartNo + 1;
            if Length(Description) > 0 then
            begin
               Log('   ' + Description);
            end;
         end
         else
         begin
            if PartNo = 0 then
            begin
               Done := True;
            end;
            break;
         end;
      end;
      DriveNo := DriveNo + 1;
   end;

   DriveNo := 0;
   while True do
   begin
      DeviceName := '\Device\Floppy' + IntToStr(DriveNo);
      if TestDevice(DeviceName, Description) then
      begin
         Log('\\?' + DeviceName);
         DriveNo := DriveNo + 1;
         if Length(Description) > 0 then
         begin
            Log('   ' + Description);
         end;
      end
      else
      begin
         break;
      end;
   end;

   DriveNo := 0;
   while True do
   begin
      DeviceName := '\Device\CdRom' + IntToStr(DriveNo);
      if TestDevice(DeviceName, Description) then
      begin
         Log('\\?' + DeviceName);
         DriveNo := DriveNo + 1;
         if Length(Description) > 0 then
         begin
            Log('   ' + Description);
         end;
      end
      else
      begin
         break;
      end;
   end;

end;


procedure PrintBlockDevices;
var
   h : THandle;
   VolumeName : String;
   MountPoints : TStringList;
   MountVolumes : TStringList;
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
               MountCount := 0;
               // see if this matches a drive letter...
               for Drive := 'a' to 'z' do
               begin
                  if VolumeLetter[Drive] = VolumeName then
                  begin
                     Log('  Mounted on ' + Drive + ':\');
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
               // find out where this volume is mounted....
               {SetLength(MountPoint, 1024);
               h2 := JFindFirstVolumeMountPoint(PChar(VolumeName), PChar(MountPoint), Length(MountPoint));
               if h2 <> INVALID_HANDLE_VALUE then
               begin
                  while True do
                  begin
                     SetLength(MountPoint, strlen(PChar(MountPoint)));
                     Log('  Mounted on ' + MountPoint);
                     MountCount := MountCount + 1;
                     SetLength(MountPoint, 1024);
                     if not JFindNextVolumeMountPoint(h2, PChar(MountPoint), Length(MountPoint)) then break;
                  end;
                  JFindVolumeMountPointClose(h2);
               end;}

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
      except
         on E : Exception do
         begin
            // Volumes are not supported under NT4
         end;
      end;
      PrintNT4BlockDevices;
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
   Result := StrToInt64(S);
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
      Result := 0;
   end
end;

var
   i : Integer;
   Value : String;
begin
   UseWriteln;
   Log('rawwrite dd for windows version ' + AppVersion + '.  Written by John Newbigin <jn@it.swin.edu.au>');
   Log('This program is covered by the GPL.  See copying.txt for details');
   
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
   BlockSize := 512; // ?
   Seek      := 0;
   Skip      := 0;
   // count=
   // if=
   // of=
   // seek=
   // skip=
   // bs=
   // --list
   for i := 1 to ParamCount do
   begin
      //Log(ParamStr(i));
      if ParamStr(i) = '--list' then
      begin
         Action := 'list';
      end
      else if StartsWith(ParamStr(i), 'count=', Value) then
      begin
         Count := StrToInt64(Value);
      end
      else if StartsWith(ParamStr(i), 'if=', Value) then
      begin
         InFile := Value;
      end
      else if StartsWith(ParamStr(i), 'of=', Value) then
      begin
         OutFile := Value;
      end
      else if StartsWith(ParamStr(i), 'seek=', Value) then
      begin
         Seek := StrToInt64(Value);
      end
      else if StartsWith(ParamStr(i), 'skip=', Value) then
      begin
         Skip := StrToInt64(Value);
      end
      else if StartsWith(ParamStr(i), 'bs=', Value) then
      begin
         BlockSize := GetBlockSize(Value);
      end
      else
      begin
         Log('Unknown command ' +  ParamStr(i));
         Action := 'usage';
      end;
   end;

   if (Action = 'dd') and (Length(InFile) = 0) then
   begin
      Action := 'usage';
   end;

//   Log('Action is ' + Action);
   if Action = 'usage' then
   begin
      PrintUsage;
   end
   else if Action = 'list' then
   begin
      PrintBlockDevices;
   end
   else if Action = 'dd' then
   begin
      Count := Count;
      Skip  := Skip * BlockSize;
      Seek  := Seek * Blocksize;
      if BlockSize > 0 then
      begin
         DoDD(InFile, OutFile, BlockSize, Count, Skip, Seek);
      end;
   end
   else
   begin
      Log('Unknown action ' + Action);
   end;
end.
