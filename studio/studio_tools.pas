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
procedure PrintVolumeGeometry;

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

// This does not even work... I'll try something else...
{procedure StrechExe(ExeName : String; size : Integer);
var
   h : THandle;
   s : Integer;
   BlockSize : Integer;
   Blocks : Integer;
   Dummy : String;
begin
   Log('Making room...');
   BlockSize := 1024 * 64;
   Blocks := Size div BlockSize + 1;

   SetLength(Dummy, BlockSize * Blocks);

   for s := 1 to Blocks do
   begin
      h := BeginUpdateResource(PChar(ExeName), False);
      //Log(IntToStr(s * BlockSize));
      UpdateResource(h, 'DISK', 'DUMMY', 0, PChar(Dummy), s * BlockSize);
      EndUpdateResource(h, False);
   end;
   h := BeginUpdateResource(PChar(ExeName), False);
   UpdateResource(h, 'DISK', 'DUMMY', 0, nil, 0);
   EndUpdateResource(h, False);
end;}

// Data should already be compressed
{
function SaveDiskResource(ExeName : String; Name : TStringList; Data : TStringList) : Boolean;
var
   h : THandle;
   i : Integer;
begin
   Result := True;
   h := BeginUpdateResource(PChar(ExeName), False);
   if h > 0 then
   begin
      Log('Begin update for ' + ExeName);
      for i := 0 to Name.Count - 1 do
      begin
         //Log(IntToStr(Length(Data[i])));
         if UpdateResource(h, 'DISK', PChar(Name[i]), 0, PChar(Data[i]), Length(Data[i])) then
         begin
            Log('Updated ' + Name[i]);
         end
         else
         begin
            ShowError('UpdateResource');
            Result := False;
            break;
         end;
      end;

      if Result then
      begin
         if EndUpdateResource(h, False) then
         begin
            Result := True;
            Log('Finished');
         end
         else
         begin
            // error
            ShowError('EndUpdateResource');
            Result := False;
         end;
      end
      else
      begin
         // error
         if not EndUpdateResource(h, True) then
         begin
            ShowError('EndUpdateResource');
         end;
         Result := False;
         Log('Aborted');
      end;
   end
   else
   begin
      ShowError('BeginUpdateResource');
      Result := False;
   end;
end;
}

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
      PEResourceModule.LoadFromFile(ExeName);
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
   Stub := ZDecompressStr(Stub);
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
                  InBinFile.AssignHandle(h);
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
            //Log('Writing block ' + IntToStr(i) + ' len = ' + IntToStr(Actual));
            if assigned(OutBinFile) then
            begin
               Actual2 := OutBinFile.BlockWrite2(PChar(Buffer), Actual);
            end;
            if assigned(Out95Disk) then
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

procedure PrintVolumeGeometry;
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

//      h := NTCreateFile(PChar(DeviceName), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_FLAG_RANDOM_ACCESS, 0);
      h := CreateFile(PChar(DeviceName), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, 0, 0);

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
{   DriveNo := 0;

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
   end;}

   DeviceName := '\\.\Volume{63e0fec2-8788-11d6-9224-806d6172696f}';

      if TestDevice(DeviceName, Description) then
      begin
         Log('\\?' + DeviceName);
         if Length(Description) > 0 then
         begin
            Log('   ' + Description);
         end;

   end;
end;


{
   boot.img,x86 boot disk,For CD install where booting from CD is not supported,TRUE
   boot_drv.img,x86 driver disk,Extra drivers for x86 boot disk,FALSE
   bootnet.img,x86 network boot disk,For Network installs,FALSE
}

end.
