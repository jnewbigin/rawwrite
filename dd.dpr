program dd;
{$APPTYPE CONSOLE}
uses
  SysUtils,
  Windows,
  Classes,
  Native in 'Native.pas',
  volume in 'volume.pas',
  WinBinFile in 'WinBinFile.pas',
  WinIOCTL in 'WinIOCTL.pas';

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

procedure ShowError(Action : String);
begin
   Debug('Error ' + Action + ': ' + IntToStr(Windows.GetLastError) + ' ' + SysErrorMessage(Windows.GetLastError));
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
         //Debug('Mount point = ' + Buffer);

         Buffer := Volume + Buffer;
         List.Add(Buffer);

         SetLength(Buffer, 1024);
         if not JFindNextVolumeMountPoint(vh, PChar(Buffer), Length(Buffer)) then
         begin
            JFindVolumeMountPointClose(vh);
            vh := INVALID_HANDLE_VALUE;
         end;
      end;
      //Debug('No more mount points');
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
      //Debug('FindVolume' + Buffer);
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
   Actual     : DWORD;

   function TestDevice(DeviceName : String) : Boolean;
   var
      h : THandle;
   begin
      Result := False;

      h := NTCreateFile(PChar(DeviceName), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_FLAG_RANDOM_ACCESS, 0);

      if h <> INVALID_HANDLE_VALUE then
      begin
         try
            Debug('Opened ' + DeviceName);
            Result := True;
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
         if TestDevice(DeviceName) then
         begin
            Debug('\\?' + DeviceName);
            PartNo := PartNo + 1;
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
      if TestDevice(DeviceName) then
      begin
         Debug('\\?' + DeviceName);
         DriveNo := DriveNo + 1;
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
      if TestDevice(DeviceName) then
      begin
         Debug('\\?' + DeviceName);
         DriveNo := DriveNo + 1;
      end
      else
      begin
         break;
      end;
   end;

end;


procedure PrintBlockDevices;
var
   h, h2 : THandle;
   VolumeName : String;
   MountPoint : String;
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
      Debug('--list is not available for Win95');
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
            //Debug('mp=' + MountPoints[i]);
            SetLength(Buffer, 1024);
            if JGetVolumeNameForVolumeMountPoint(PChar(MountPoints[i]), PChar(Buffer), Length(Buffer)) then
            begin
               SetLength(Buffer, strlen(PChar(Buffer)));
               MountVolumes.Add(Buffer);
               //Debug('   ' + Buffer);
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
               // see if this matches a mount point...
               for i := 0 to MountPoints.Count - 1 do
               begin
                  if MountVolumes[i] = VolumeName then
                  begin
                     Debug('  Mounted on ' + MountPoints[i]);
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
                     Debug('  Mounted on ' + MountPoint);
                     MountCount := MountCount + 1;
                     SetLength(MountPoint, 1024);
                     if not JFindNextVolumeMountPoint(h2, PChar(MountPoint), Length(MountPoint)) then break;
                  end;
                  JFindVolumeMountPointClose(h2);
               end;}

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
      except
         on E : Exception do
         begin
            // Volumes are not supported under NT4
         end;
      end;
      PrintNT4BlockDevices;
   end;

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
   Actual : DWORD;
   Actual2 : DWORD;

   Buffer : String;
   i : Integer;

   FullBlocksIn : Int64;
   HalfBlocksIn : Int64;
   FullBlocksOut : Int64;
   HalfBlocksOut : Int64;
begin
   Debug('InFile    = ' + InFile);
   Debug('OutFile   = ' + OutFile);
   Debug('BlockSize = ' + IntToStr(BlockSize));
   Debug('Count     = ' + IntToStr(Count));
   Debug('Skip      = ' + IntToStr(Skip));
   Debug('Seek      = ' + IntToStr(Seek));

   FullBlocksIn  := 0;
   HalfBlocksIn  := 0;
   FullBlocksOut := 0;
   HalfBlocksOut := 0;
   // open the files....
   InBinFile := TBinaryFile.Create;
   if StartsWith(InFile, '\\?\', Value) then
   begin
      // do a native open
      Value := '\' + Value;
      //Debug('ntopen ' + Value);
      h := NTCreateFile(PChar(Value), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_FLAG_RANDOM_ACCESS, 0);
      if h <> INVALID_HANDLE_VALUE then
      begin
         InBinFile.AssignHandle(h);
      end
      else
      begin
         ShowError('native opening input file');
         exit;
      end;
   end
   else
   begin
      // winbinfile it
      Debug('open ' + InFile);
      InBinFile.Assign(InFile);
      if not InBinFile.Open(OPEN_READ_ONLY) then
      begin
         ShowError('opening input file');
         exit;
      end;
   end;

   // skip over the required amount of input
   if Skip > 0 then
   begin
      InBinFile.Seek(Skip);
      Debug('skip to ' + IntToStr(InBinFile.GetPos));
   end;

   // open the output file
   OutBinFile := TBinaryFile.Create;
   if StartsWith(InFile, '\\?\', Value) then
   begin
      Debug('Native write NYI');
{      // do a native open
      Value := '\' + Value;
      //Debug('ntopen ' + Value);
      h := NTCreateFile(PChar(Value), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_FLAG_RANDOM_ACCESS, 0);
      if h <> INVALID_HANDLE_VALUE then
      begin
         InBinFile.AssignHandle(h);
      end
      else
      begin
         ShowError('native opening file');
         exit;
      end;}
   end
   else
   begin
      // winbinfile it
      Debug('open ' + OutFile);
      OutBinFile.Assign(OutFile);
      if not OutBinFile.CreateNew then
      begin
         if not OutBinFile.Open(OPEN_WRITE_ONLY) then
         begin
            ShowError('opening output file');
            exit;
         end;
      end;
   end;

   // seek over the required amount of output
   if Seek > 0 then
   begin
      OutBinFile.Seek(Seek);
      Debug('seek to ' + IntToStr(OutBinFile.GetPos));
   end;


   i := 0;
   while (i < Count) or (Count = -1) do
   begin
      Debug('Reading block ' + IntToStr(i) + ' len = ' + IntToStr(BlockSize));
      SetLength(Buffer, BlockSize);
      Actual := InBinFile.BlockRead2(PChar(Buffer), BlockSize);
      Debug('actual = ' + IntToStr(Actual));
      if Actual = BlockSize then
      begin
         FullBlocksIn := FullBlocksIn + 1;
      end
      else if Actual > 0 then
      begin
         HalfBlocksIn := HalfBlocksIn + 1;
      end
      else
      begin
         if Windows.GetLastError > 0 then
         begin
            ShowError('reading file');
         end;
         break;
      end;


      // write the output...
      Debug('Writing block ' + IntToStr(i) + ' len = ' + IntToStr(Actual));
      Actual2 := OutBinFile.BlockWrite2(PChar(Buffer), Actual);
      if Actual2 = Actual then
      begin
         // full write
         if Actual2 = BlockSize then
         begin
            FullBlocksOut := FullBlocksOut + 1;
         end
         else
         begin
            HalfBlocksOut := HalfBlocksOut + 1;
         end;
      end
      else if Actual2 > 0 then
      begin
         // partial write
         // this is half of a half, what do we call that???
         HalfBlocksOut := HalfBlocksOut + 2; // ??
      end
      else
      begin
         if Windows.GetLastError > 0 then
         begin
            ShowError('writing file');
         end;
         break;
      end;

      i := i + 1;
//      Debug(Buffer);
   end;

   Debug(IntToStr(FullBlocksIn)  + '+' + IntToStr(HalfBlocksIn)  + ' records in');
   Debug(IntToStr(FullBlocksOut) + '+' + IntToStr(HalfBlocksOut) + ' records out');


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
   //Debug(' n = ' + S);
   Result := StrToInt64(S);
   //Debug(' s = ' + Suffix);
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
      Debug('Unknown suffix ' + Suffix);
      Result := 0;
   end
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
         BlockSize := GetBlockSize(Value);
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
      Debug('Unknown action ' + Action);
   end;
end.
