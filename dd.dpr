program dd;
{$APPTYPE CONSOLE}
uses
  SysUtils,
  Windows,
  Classes,
  Native in 'Native.pas',
  volume in 'volume.pas',
  WinBinFile in 'WinBinFile.pas';

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

procedure Debug(S : String);
begin
   writeln(S);
end;

procedure PrintUsage;
begin
   Debug('dd [bs=BYTES] [count=BLOCKS] [if=FILE] [of=FILE] [seek=BLOCKS] [skip=BLOCKS] [--list]');
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
         Debug('Mount point = ' + Buffer);

         Buffer := Volume + Buffer;
         List.Add(Buffer);

         SetLength(Buffer, 1024);
         if not JFindNextVolumeMountPoint(vh, PChar(Buffer), Length(Buffer)) then
         begin
            JFindVolumeMountPointClose(vh);
            vh := INVALID_HANDLE_VALUE;
         end;
      end;
      Debug('No more mount points');
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
      Debug('FindVolume' + Buffer);
      EnumerateVolumeMountPoints(Buffer);

      SetLength(Buffer, 1024);
      if not JFindNextVolume(h, PChar(Buffer), Length(Buffer)) then
      begin
         JFindVolumeClose(h);
         h := INVALID_HANDLE_VALUE;
      end;
   end;
end;


procedure PrintBlockDevices;
var
   h, h2 : THandle;
   VolumeName : String;
   MountPoint : String;
   MountPoints : TStringList;
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
      Debug('--list is not available for Win95');
   end
   else
   begin
      LoadVolume;
{      MountPoints := TStringList.Create;
      GetListOfMountPoints(MountPoints);
      for i := 0 to MountPoints.Count - 1 do
      begin
         Debug('mp=' + MountPoints[i]);
      end;}

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
//               Debug(DriveString + ' = ' + Buffer);
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
            Debug('\\.\' + Copy(VolumeName, 5, Length(VolumeName)));
            MountCount := 0;
            // see if this matches a drive letter...
            for Drive := 'a' to 'z' do
            begin
               if VolumeLetter[Drive] = VolumeName then
               begin
                  Debug('  Mounted on ' + Drive + ':\');
                  MountCount := MountCount + 1;
               end;
            end;
            // find out where this volume is mounted....
            SetLength(MountPoint, 1024);
            h2 := JFindFirstVolumeMountPoint(PChar(VolumeName), PChar(MountPoint), Length(MountPoint));
            if h2 <> INVALID_HANDLE_VALUE then
            begin
               while True do
               begin
                  SetLength(MountPoint, strlen(PChar(MountPoint)));
                  Debug('  Mounted on ' + MountPoint);
                  MountCount := MountCount + 1;
                  SetLength(MountPoint, 1024);
                  if not JFindNextVolumeMountPoint(h2, PChar(MountPoint), Length(MountPoint)) then break;
               end;
               JFindVolumeMountPointClose(h2);
            end;

            if MountCount = 0 then
            begin
               Debug('  Not mounted');
            end;

            Debug('');

            SetLength(VolumeName, 1024);
            if not JFindNextVolume(h, PChar(VolumeName), Length(VolumeName)) then break;
         end;
         JFindVolumeClose(h);
      end;
   end;
   
end;

procedure ShowError;
begin
   Debug('Error reading file ' + IntToStr(Windows.GetLastError) + ' ' + SysErrorMessage(Windows.GetLastError));
end;

function StartsWith(S : String; Start : String; var Value : String) : Boolean;
var
   p : Integer;
begin
   p := Pos(Start, S);
   if p = 1 then
   begin
      Result := True;
      Value := Copy(S, p + Length(Start), Length(S));
   end
   else
   begin
      Result := False;
   end;
end;

procedure DoDD(InFile : String; OutFile : String; BlockSize : Int64; Count : Int64; Skip : Int64; Seek : int64);
var
   InBinFile   : TBinaryFile;
   OutBinFile  : TBinaryFile;

   Value : String;
   h : THandle;

   Buffer : String;
   i : Integer;
begin
   // open the files....
   InBinFile := TBinaryFile.Create;
   if StartsWith(InFile, '\\?\', Value) then
   begin
      // do a native open
      Value := '\??\' + Value;
      Debug('ntopen ' + Value);
      h := NTCreateFile(PChar(Value), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_FLAG_RANDOM_ACCESS, 0);
      if h <> INVALID_HANDLE_VALUE then
      begin
         InBinFile.AssignHandle(h);
      end
      else
      begin
         ShowError;
         exit;
      end;
   end
   else
   begin
      // winbinfileit
      Debug('open ' + InFile);
      InBinFile.Assign(InFile);
      if not InBinFile.Open(OPEN_READ_ONLY) then
      begin
         ShowError;
         exit;
      end;
   end;

   // skip over the required amount of input
   if Skip > 0 then
   begin
      InBinFile.Seek(Skip);
      Debug('skip to ' + IntToStr(InBinFile.GetPos));
   end;

   for i := 1 to Count do
   begin
      Debug('Reading block ' + IntToStr(i) + ' len = ' + IntToStr(BlockSize));
      SetLength(Buffer, BlockSize);
      if InBinFile.BlockRead2(PChar(Buffer), BlockSize) <> BlockSize then
      begin
         ShowError;
         exit;
      end;
//      Debug(Buffer);
   end;


end;

var
   i : Integer;
   Value : String;
begin
   writeln('rawwrite dd for windows.  Written by John Newbigin <jn@it.swin.edu.au>');
   
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
      Debug('Could not get Version info!');
   end;

   // check the command line parameters
   Action := 'dd';
   Count := -1;
   BlockSize := 1;
   // count=
   // if=
   // of=
   // seek=
   // skip=
   // bs=
   // --list
   for i := 1 to ParamCount do
   begin
      //Debug(ParamStr(i));
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
         BlockSize := StrToInt64(Value);
      end
      else
      begin
         Debug('Unknown command ' +  ParamStr(i));
         Action := 'usage';
      end;
   end;

//   Debug('Action is ' + Action);
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
      Count := Count * BlockSize;
      Skip  := Skip * BlockSize;
      Seek  := Seek * Blocksize;
      DoDD(InFile, OutFile, BlockSize, Count, Skip, Seek);
   end
   else
   begin
      Debug('Unknown action ' + Action);
   end;

   readln;

end.