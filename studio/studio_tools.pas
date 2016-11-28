unit studio_tools;

{$IFDEF FPC}
{$MODE Delphi}
{$ENDIF}

interface

{$IFDEF WIN32}
uses windows, classes;
{$ELSE}
uses classes;
{$ENDIF}

const AppVersion = '0.6beta3';

type
ProgressEvent = function (Progress : Int64; Error : DWORD) : Boolean of object;

function LoadDiskFile(FileName : String) : String;
procedure SaveDiskFile(FileName : String; Data : String);
function LoadDiskResource(Name : String) : String;
function SaveDiskResource(ExeName : String; Name : TStringList; Data : TStringList) : Boolean;
procedure CreateExe(FileName : String; Stub : String);
procedure ShowError(Action : String);
function GetSize(h : THandle) : Int64;
procedure DoDD(InFile : String; OutFile : String; BlockSize : Int64; Count : Int64; Skip : Int64; Seek : int64; NoTruncateOut : Boolean; StopType : Boolean; Callback : ProgressEvent);
function StartsWith(S : String; Start : String; var Value : String) : Boolean;
function EndsWith(S : String; Ends : String; var Value : String) : Boolean;
function GetDriveStrings(StringList : TStringList) : Boolean;
function GetDriveTypeDescription(DriveType : Integer) : String;

implementation

{$IFDEF WIN32}
uses zlib, sysutils, debug, native, winbinfile, diskio, md5, dialogs, winioctl, persrc, MT19937;
{$ELSE}
uses zlib, sysutils, debug, UnixBinFile, md5, persrc;
{$ENDIF}

procedure ShowError(Action : String);
begin
{$IFDEF WIN32}
   Log('Error ' + Action + ': ' + IntToStr(Windows.GetLastError) + ' ' + SysErrorMessage(Windows.GetLastError));
{$ELSE}
   Log('Error ' + Action + ': perror NYI');
{$ENDIF}
end;

function LoadDiskFile(FileName : String) : String;
var
   BinFile : TBinaryFile;
begin
   BinFile := TBinaryFile.Create;
   try
      BinFile.Assign(FileName);
      BinFile.Open(OPEN_READ_ONLY);

      SetLength(Result, BinFile.FileSize);
      BinFile.BlockRead2(PChar(Result), BinFile.FileSize);
   finally
      BinFile.Free;
   end;
end;

procedure SaveDiskFile(FileName : String; Data : String);
var
   BinFile : TBinaryFile;
begin
   BinFile := TBinaryFile.Create;
   try
      BinFile.Assign(FileName);
      if not BinFile.CreateNew then
      begin
         BinFile.Open(OPEN_WRITE_ONLY);
         BinFile.TruncateTo(0);
      end;

      BinFile.BlockWrite2(PChar(Data), Length(Data));
   finally
      BinFile.Free;
   end;
end;

{$IFDEF WIN32}
function LoadDiskResource(Name : String) : String;
var
   h : THandle;
   gh : THandle;
   data : PChar;
   Res : String;
begin
   h := FindResource(0, PChar(Name), 'DISK');
   if h > 0 then
   begin
      gh := LoadResource(0, h);
      if gh > 0 then
      begin
         Data := LockResource(gh);
         if Data <> nil then
         begin
            SetLength(Res,SizeofResource(0, h));
            CopyMemory(PChar(Res), Data, Length(Res));
            //Result := ZDecompressStr(res);
            Result := Res;
         end
         else
         begin
            // error
         end;
      end
      else
      begin
         // error
      end;
   end
   else
   begin
      // error
   end;
end;
{$ELSE}
function LoadDiskResource(Name : String) : String;
begin
   // use my code to load it...
   Log('LoadDiskResource NYI');
   Result := '';
end;
{$ENDIF}


// alas, I had to write my own
// Data should already be compressed
function SaveDiskResource(ExeName : String; Name : TStringList; Data : TStringList) : Boolean;
var
   i : Integer;
   Len : Integer;
   PEFile : TPEFile;
   NewResource : TResourceTreeNode;
begin
   Result := True;

   PEFile := TPEFile.Create(ExeName);

   if Assigned(PEFile.GetRsrcRoot) then
   begin
      for i := 0 to Name.Count - 1 do
      begin
         Len := Length(Data[i]);
         Log('Adding resource ' + Name[i] + ' (' + IntToStr(Len) + ')');

         NewResource := PEFile.GetRsrcRoot.GetNodeByName('DISK');
         if not Assigned(NewResource) then
         begin
            NewResource := PEFile.GetRsrcRoot.CreateNode;
            NewResource.SetName('DISK');
         end;
         if Assigned(NewResource) then
         begin
            NewResource := NewResource.CreateNode;
            if Assigned(NewResource) then
            begin
               NewResource.SetName(Name[i]);

               // The data goes on the language node
               NewResource := NewResource.CreateNode;
               if Assigned(NewResource) then
               begin
                  NewResource.SetLeafData(Data[i], 0);
               end;
            end;
         end;
      end;
   end;

   PEFile.Save;
end;


function CopyStub(Target : String; StubFile : String) : Boolean;
var
   BinFile : TBinaryFile;
   Stub : String;
begin
   Result := false;
   if Length(StubFile) = 0 then
   begin
      Stub := LoadDiskResource('STUB');
      try
         Stub := Zlib.ZDecompressStr(Stub);
      except
      end;
      if Length(Stub) = 0 then
      begin
         exit;
      end;
   end
   else
   begin
      // use a specifc stub file
      BinFile := TBinaryFile.Create;
      try
         BinFile.Assign(StubFile);
         BinFile.Open(0);
         SetLength(Stub, BinFile.FileSize);

         BinFile.BlockRead2(PChar(Stub), Length(Stub));
         BinFile.Close;
      finally
         BinFile.Free;
      end;
   end;
   BinFile := TBinaryFile.Create;
   try
      BinFile.Assign(Target);
      BinFile.Delete;
      BinFile.CreateNew;

      BinFile.BlockWrite2(PChar(Stub), Length(Stub));
      BinFile.Close;
      Result := True;
   finally
      BinFile.Free;
   end;

end;

procedure CreateExe(FileName : String; Stub : String);
var
   Config : TStringList;
   Chopper : TStringList;
   i : Integer;
   Target : String;
   DiskName : String;
   Line : String;
   Data : String;
   ZData : String;
   TotalSize : Integer;
   Checksum : String;

   NameList : TStringList;
   DataList : TStringList;
begin
   Config := TStringList.Create;
   NameList := TStringList.Create;
   DataList := TStringList.Create;
   TotalSize := 0;
   try
      Config.LoadFromFile(FileName);
      if Config.Count > 0 then
      begin
         Target := ChangeFileExt(FileName, '.exe');
         if not CopyStub(Target, Stub) then
         begin
            Log('Can''t load stub resource.  Try using --stub');
            exit;
         end;
         for i := 1 to Config.Count - 1 do
         begin
            Line := Trim(Config[i]);
            if Length(Line) > 0 then
            begin
               Chopper := TStringList.Create;
               try
                  Chopper.CommaText := Config[i];
                  if Chopper.Count = 4 then
                  begin
                     if FileExists(Chopper[0]) then
                     begin
                     Log('Loading ' + Chopper[0]);
                     Data := LoadDiskFile(Chopper[0]);
                     Checksum := MD5Print(MD5String(Data));
                     ZData := ZCompressStr(Data, zcMax);

                     DiskName := 'DISK' + IntToStr(i);
                     Chopper.Add(DiskName);
                     Chopper.Add(Checksum);

                     NameList.Add(DiskName);
                     DataList.Add(ZData);

                     TotalSize := TotalSize + Length(ZData);

                     Config[i] := Chopper.CommaText;
                     end
                     else
                     begin
                        Log('File not found ' + Chopper[0] + ' on line ' + IntToStr(i + 1));
                     end;
                  end
                  else
                  begin
                     Log('Wrong number of arguements for line ' + IntToStr(i + 1));
                  end
               finally
                  Chopper.Free;
               end;
            end;
         end;

// we could compress the config info but it makes it hard to debug
         DataList.Add(ZCompressStr(Config.Text, zcMax));
         NameList.Add('DISKINFO');
         DataList.Add(Config.Text);

         SaveDiskResource(Target, NameList, DataList);
      end;
   finally
      Config.Free;
   end;
   Log('Compressed payload size is ' + IntToStr(TotalSize) + ' bytes');
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

function EndsWith(S : String; Ends : String; var Value : String) : Boolean;
begin
   if Copy(S, Length(S) - Length(Ends) + 1, Length(Ends)) = Ends then
   begin
      Result := True;
      Value := Copy(S, 1, Length(S) - Length(Ends));
   end
   else
   begin
      Result := False;
   end;
end;

{$IFDEF WIN32}

function GetSize(h : THandle) : Int64;
var
   NewDevice : String;
   NewOffset : Int64;
   NewLength : Int64;
begin
   if GetDiskExtents(h, NewDevice, NewOffset, NewLength) then
   begin
      Result := NewLength;
   end
   else
   begin
      Result := GetPartitionSize(h);
   end;
   if Result = 0 then
   begin
      Result := GetDiskSize(h);
   end;
end;

procedure DoDD(InFile : String; OutFile : String; BlockSize : Int64; Count : Int64; Skip : Int64; Seek : int64; NoTruncateOut : Boolean; StopType : Boolean; Callback : ProgressEvent);
var
   InBinFile   : TBinaryFile;
   OutBinFile  : TBinaryFile;

   InSize : Int64;
//   OutSize : Int64;
   ThisBlock : Int64;

   MagicZero   : Boolean;
   MagicRandom : Boolean;
   StdOut      : Boolean;
   MagicNull   : Boolean;

   In95Disk : T95Disk;
   Out95Disk : T95Disk;
   Out95SectorCount : LongInt;

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
   BytesOut : Int64;

   StdinSkip : Int64;
begin
//   Log('InFile    = ' + InFile);
//   Log('OutFile   = ' + OutFile);
//   Log('BlockSize = ' + IntToStr(BlockSize));
//   Log('Count     = ' + IntToStr(Count));
//   Log('Skip      = ' + IntToStr(Skip));
//   Log('Seek      = ' + IntToStr(Seek));

   FullBlocksIn  := 0;
   HalfBlocksIn  := 0;
   FullBlocksOut := 0;
   HalfBlocksOut := 0;
   BytesOut      := 0;

   InBinFile  := nil;
   InSize     := 0;
   OutBinFile := nil;
   In95Disk   := nil;
   Out95Disk  := nil;
   Out95SectorCount := 0;

   MagicZero   := False;
   MagicRandom := False;
   StdOut      := False;
   MagicNull   := False;
   // open the files....
   InBinFile := TBinaryFile.Create;
   try
      if InFile = '/dev/zero' then
      begin
         MagicZero := True;
      end
      else if InFile = '/dev/random' then
      begin
         MagicRandom := True;
         randomize_MT19937;
      end
      else if InFile = '-' then
      begin
         h := GetStdHandle(STD_INPUT_HANDLE);
         if h <> INVALID_HANDLE_VALUE then
         begin
            InBinFile.AssignHandle(h);
         end
         else
         begin
            ShowError('native opening standard input');
            exit;
         end;
      end
      else if StartsWith(InFile, '\\:\', Value) then
      begin
         // a resource name
         Log('NYI Reading DISK ' + Value);
         exit;
      end
      else if StartsWith(InFile, '\\?\', Value) then
      begin
         // do a native open
         Value := '\' + Value;
         //Log('ntopen ' + Value);
         h := NTCreateFile(PChar(Value), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_FLAG_RANDOM_ACCESS, 0);
         if h <> INVALID_HANDLE_VALUE then
         begin
            InBinFile.AssignHandle(h);
            if StopType then
            begin
               InSize := GetSize(h);
            end;
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

         // special 95 block device access
         if (Length(InFile) = 2) and (InFile[2] = ':') then
         begin
            Log('read 95 disk NYI');
         end;

         //Log('open ' + InFile);
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
         if InFile = '-' then
         begin
            // can't seek on stdin, we will just read it...
            StdinSkip := Skip;
            while StdinSkip > 0 do
            begin
               SetLength(Buffer, BlockSize);

               Actual := InBinFile.BlockRead2(PChar(Buffer), BlockSize);
               // error checking?
               StdinSkip := StdinSkip - BlockSize;
            end;

         end
         else
         begin
            InBinFile.Seek(Skip);
            Log('skip to ' + IntToStr(InBinFile.GetPos));
         end;
      end;

      // open the output file
      try
         if (Length(OutFile) = 2) and (OutFile[2] = ':') then
         begin
            Log('read from 95 disk');
            Out95Disk := T95Disk.Create;
            Out95Disk.SetDiskByName(OutFile);
            Out95SectorCount := 0;
         end
         else
         begin
            OutBinFile := TBinaryFile.Create;

            if OutFile = '/dev/null' then
            begin
               MagicNull := True;
            end
            else if OutFile = '-' then
            begin
               h := GetStdHandle(STD_OUTPUT_HANDLE);
               if h <> INVALID_HANDLE_VALUE then
               begin
                  OutBinFile.AssignHandle(h);
               end
               else
               begin
                  ShowError('native opening standard output');
                  exit;
               end;
            end
            else if StartsWith(OutFile, '\\?\', Value) then
            begin
         //      Log('Native write NYI');
               // do a native open
               Value := '\' + Value;
               //Log('ntopen ' + Value);
               h := NTCreateFile(PChar(Value), GENERIC_WRITE, 0, nil, OPEN_EXISTING, FILE_FLAG_RANDOM_ACCESS, 0);
               if h <> INVALID_HANDLE_VALUE then
               begin
                  OutBinFile.AssignHandle(h);
               end
               else
               begin
                  ShowError('native opening file');
                  exit;
               end;
            end
            else
            begin
               // winbinfile it

               //Log('open ' + OutFile);
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
         end;

         // seek over the required amount of output
         if Seek > 0 then
         begin
            if Assigned(OutBinFile) then
            begin
               if not MagicNull then
               begin
                  OutBinFile.Seek(Seek);
               end;
            end
            else if Assigned(Out95Disk) then
            begin
               Out95SectorCount := Seek div 512;
            end;
            //Log('seek to ' + IntToStr(OutBinFile.GetPos));
         end;

         if Assigned(Callback) then
         begin
            Callback(BytesOut, Windows.GetLastError);
         end;

         i := 0;
         while (i < Count) or (Count = -1) do
         begin

            ThisBlock := BlockSize;
            if StopType and (InSize > 0) then
            begin
               // for USB devices, make sure we don't read past the end of the device
               if Skip + ((i + 1) * BlockSize) > InSize then
               begin
                  // we need to recuce the read size...
                  ThisBlock := InSize - (Skip + (i * BlockSize));
               end;
            end;
            //Log('Reading block ' + IntToStr(i) + ' len = ' + IntToStr(BlockSize));
            SetLength(Buffer, BlockSize);
            if MagicZero then
            begin
               FillMemory(PChar(Buffer), BlockSize, 0);
               Actual := BlockSize;
            end
            else if MagicRandom then
            begin
               FillBuffer_MT19937(PChar(Buffer), BlockSize);
               Actual := BlockSize;
            end
            else
            begin
               Actual := InBinFile.BlockRead2(PChar(Buffer), ThisBlock);
            end;
            //Log('actual = ' + IntToStr(Actual));
            if Actual = BlockSize then
            begin
               FullBlocksIn := FullBlocksIn + 1;
            end
            else if Actual > 0 then // many USB devices don;t support this...
            begin
               HalfBlocksIn := HalfBlocksIn + 1;
            end
            else
            begin
               if Windows.GetLastError > 0 then
               begin
                  if Windows.GetLastError = 109 then
                  begin
                     // End of pipe
                  end
                  else
                  begin
                     ShowError('reading file');
                  end;
               end;
               break;
            end;

            // write the output...
            //Log('Writing block ' + IntToStr(i) + ' len = ' + IntToStr(Actual));
            if assigned(OutBinFile) then
            begin
               if MagicNull then
               begin
                  Actual2 := Actual;
               end
               else
               begin
                  Actual2 := OutBinFile.BlockWrite2(PChar(Buffer), Actual);
                  if (Actual2 = 0) and (Actual <> BlockSize) then
                  begin
                     if Windows.GetLastError = 87 then
                     begin
                        // non aligned writes don't work on block devices...
                        // round up and try again
                        FillMemory(PChar(Buffer) + Actual, BlockSize - Actual, 0);
                        Actual2 := OutBinFile.BlockWrite2(PChar(Buffer), BlockSize);
                        if Actual2 = BlockSize then
                        begin
                           Actual2 := Actual;
                        end;
                     end;
                  end;
               end;
            end
            else if assigned(Out95Disk) then
            begin
               if Out95Disk.WriteSector(Out95SectorCount, PChar(Buffer), Actual div 512) then
               begin
                  Actual2 := Actual;
                  Out95SectorCount := Out95SectorCount + (Actual div 512);
               end
               else
               begin
                  Actual2 := 0;
               end;
            end
            else
            begin
               // no device to write to... must be an error
               Actual2 := 0;
            end;
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
                  if Assigned(Callback) then
                  begin
                     if Callback(BytesOut, Windows.GetLastError) then
                     begin
                        break;
                     end;
                  end;
               end;
               break;
            end;

            BytesOut := BytesOut + Actual2;
            if Assigned(Callback) then
            begin
               if Callback(BytesOut, 0) then
               begin
                  break;
               end;
            end;

            if ThisBlock < BlockSize then
            begin
               break;
            end;

            i := i + 1;
      //      Log(Buffer);
         end;
         if Assigned(Callback) then
         begin
            Log('');
         end;
         Log(IntToStr(FullBlocksIn)  + '+' + IntToStr(HalfBlocksIn)  + ' records in');
         Log(IntToStr(FullBlocksOut) + '+' + IntToStr(HalfBlocksOut) + ' records out');
      finally
         if Assigned(OutBinFile) then
         begin
            OutBinFile.Free;
         end;
      end;
   finally
      if Assigned(InBinFile) then
      begin
         InBinFile.Free;
      end;
   end;

end;
{$ELSE}
procedure DoDD(InFile : String; OutFile : String; BlockSize : Int64; Count : Int64; Skip : Int64; Seek : int64; Callback : ProgressEvent);
begin
end;
{$ENDIF}

{$IFDEF WIN32}
function GetDriveStrings(StringList : TStringList) : Boolean;
var
   Error : DWORD;
   Buffer : String;
   i : DWORD;
   S : String;
   DriveType : UINT;
begin
   SetLength(Buffer, 4096);
   Error := GetLogicalDriveStrings(Length(Buffer), PCHAR(Buffer));
   if Error = 0 then
   begin
      Result := false;
      exit;
   end;

   SetLength(Buffer, Error);

   S := '';
   i := 1;
   while i <= Error do
   begin
      if Buffer[i] = #0 then
      begin
         DriveType := GetDriveType(PCHAR(S));
         StringList.AddObject(S, TObject(DriveType));
         S := '';
      end
      else
      begin
         S := S + Buffer[i];
      end;
      i := i + 1;
   end;

   Result := True;

end;

// Pass in the drive type as returned by GetDriveStrings or GetDriveType
function GetDriveTypeDescription(DriveType : Integer) : String;
begin
   case DriveType of
      DRIVE_UNKNOWN:       Result := 'drive type cannot be determined';
      DRIVE_NO_ROOT_DIR:   Result := 'no volume mounted';
      DRIVE_REMOVABLE:     Result := 'removeable media';
      DRIVE_FIXED:         Result := 'fixed media';
      DRIVE_REMOTE:        Result := 'network drive';
      DRIVE_CDROM:         Result := 'CD-ROM';
      DRIVE_RAMDISK:       Result := 'RAM disk';
   else
      Result := 'Unknown';
   end;
end;
{$ELSE}
function GetDriveStrings(StringList : TStringList) : Boolean;
begin
   StringList.Add('/');
   Result := True;
end;

function GetDriveTypeDescription(DriveType : Integer) : String;
begin
   Result := 'Fileststem';
end;
{$ENDIF}

{
   boot.img,x86 boot disk,For CD install where booting from CD is not supported,TRUE
   boot_drv.img,x86 driver disk,Extra drivers for x86 boot disk,FALSE
   bootnet.img,x86 network boot disk,For Network installs,FALSE
}

end.
