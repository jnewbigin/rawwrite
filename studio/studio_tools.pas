unit studio_tools;

interface
uses windows, classes;

const AppVersion = '0.3';

type
ProgressEvent = function (Progress : Int64; Error : DWORD) : Boolean of object;

function LoadDiskFile(FileName : String) : String;
procedure SaveDiskFile(FileName : String; Data : String);
function LoadDiskResource(Name : String) : String;
function SaveDiskResource(ExeName : String; Name : TStringList; Data : TStringList) : Boolean;
procedure CreateExe(FileName : String);
procedure ShowError(Action : String);
procedure DoDD(InFile : String; OutFile : String; BlockSize : Int64; Count : Int64; Skip : Int64; Seek : int64; Callback : ProgressEvent);
function StartsWith(S : String; Start : String; var Value : String) : Boolean;
function EndsWith(S : String; Ends : String; var Value : String) : Boolean;
function GetDriveStrings(StringList : TStringList) : Boolean;
function GetDriveTypeDescription(DriveType : Integer) : String;

implementation

uses zlib, sysutils, debug, native, winbinfile, diskio, unitPEFile,
     unitResourceDetails, md5, dialogs, winioctl;

procedure ShowError(Action : String);
begin
   Log('Error ' + Action + ': ' + IntToStr(Windows.GetLastError) + ' ' + SysErrorMessage(Windows.GetLastError));
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


// This implementation uses ResourceUtils http://www.wilsonc.demon.co.uk/d7resourceutils.htm
// Data should already be compressed
function SaveDiskResource(ExeName : String; Name : TStringList; Data : TStringList) : Boolean;
var
   i : Integer;
   PEResourceModule : TPEResourceModule;
   NewResource : TResourceDetails;
   Len : Integer;
begin
   Result := True;

   PEResourceModule := TPEResourceModule.Create;
   PEResourceModule.LoadFromFile(ExeName);


   // dump out the current resources...

   //Log('Resource count = ' + IntToStr(PEResourceModule.ResourceCount));
{   for i := 0 to PEResourceModule.ResourceCount - 1 do
   begin
      Log(PEResourceModule.ResourceDetails[i].ResourceName);
      Log(PEResourceModule.ResourceDetails[i].ResourceType);
      //PEResourceModule.ResourceDetails[i].Parent
   end;}


{   Log('Deleting DISK resources');
   i := 0;
   while i < PEResourceModule.ResourceCount do
   begin
      if PEResourceModule.ResourceDetails[i].ResourceType = 'DISK' then
      begin
         Log('Deleting resource called ' + PEResourceModule.ResourceDetails[i].ResourceName);
         PEResourceModule.DeleteResource(i);
      end
      else
      begin
         i := i + 1;
      end;
   end;}

   for i := 0 to Name.Count - 1 do
   begin
      Len := Length(Data[i]);
      Log('Adding resource ' + Name[i] + ' (' + IntToStr(Len) + ')');
      NewResource := TResourceDetails.CreateResourceDetails(PEResourceModule, 0, Name[i], 'DISK', Len, PChar(Data[i]));
      PEResourceModule.AddResource(NewResource);
   end;

   PEResourceModule.SaveToFile(ExeName);
   PEResourceModule.Free;
end;


procedure CopyStub(Target : String);
var
   BinFile : TBinaryFile;
   Stub : String;
begin
   Stub := LoadDiskResource('STUB');
   try
      Stub := ZDecompressStr(Stub);
   except
   end;
   BinFile := TBinaryFile.Create;
   try
      BinFile.Assign(Target);
      BinFile.Delete;
      BinFile.CreateNew;

      BinFile.BlockWrite2(PChar(Stub), Length(Stub));
      BinFile.Close;
   finally
      BinFile.Free;
   end;

end;

procedure CreateExe(FileName : String);
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
         CopyStub(Target);
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
                     Log('Wrong number of arguements for line ' + IntToStr(i + 1));
                  end
               finally
                  Chopper.Free;
               end;
            end;
         end;

// we could compress the config info but it makes it hard to debug
//         DataList.Add(ZCompressStr(Config.Text, zcMax));
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

procedure DoDD(InFile : String; OutFile : String; BlockSize : Int64; Count : Int64; Skip : Int64; Seek : int64; Callback : ProgressEvent);
var
   InBinFile   : TBinaryFile;
   OutBinFile  : TBinaryFile;

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
   OutBinFile := nil;
   In95Disk   := nil;
   Out95Disk  := nil;
   Out95SectorCount := 0;
   // open the files....
   InBinFile := TBinaryFile.Create;
   try
      if StartsWith(InFile, '\\:\', Value) then
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
         InBinFile.Seek(Skip);
         //Log('skip to ' + IntToStr(InBinFile.GetPos));
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

            if StartsWith(OutFile, '\\?\', Value) then
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
               OutBinFile.Seek(Seek);
            end
            else if Assigned(Out95Disk) then
            begin
               Out95SectorCount := Seek div 512;
            end;
            //Log('seek to ' + IntToStr(OutBinFile.GetPos));
         end;


         i := 0;
         while (i < Count) or (Count = -1) do
         begin
            //Log('Reading block ' + IntToStr(i) + ' len = ' + IntToStr(BlockSize));
            SetLength(Buffer, BlockSize);
            Actual := InBinFile.BlockRead2(PChar(Buffer), BlockSize);
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
                  ShowError('reading file');
               end;
               break;
            end;

            // write the output...
            //Log('Writing block ' + IntToStr(i) + ' len = ' + IntToStr(Actual));
            if assigned(OutBinFile) then
            begin
               Actual2 := OutBinFile.BlockWrite2(PChar(Buffer), Actual);
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

{
   boot.img,x86 boot disk,For CD install where booting from CD is not supported,TRUE
   boot_drv.img,x86 driver disk,Extra drivers for x86 boot disk,FALSE
   bootnet.img,x86 network boot disk,For Network installs,FALSE
}

end.
