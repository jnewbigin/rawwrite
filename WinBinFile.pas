unit WinBinFile;
// $Header: /home/cso/jnewbigin/cvsroot/rawwrite/WinBinFile.pas,v 1.4 2005/01/21 12:07:33 jnewbigin Exp $


interface

uses Windows, WinIOCTL;

const OPEN_READ_ONLY = 0;
const OPEN_READ_WRITE = 1;
const OPEN_WRITE_ONLY = 2;

type
   TBinaryFile = class
      private
         FileName : String;
         F        : THandle;
         IsOpen   : Boolean;
      public
         constructor Create;
         destructor Destroy; override;

         procedure Assign(Name : String);
         procedure AssignHandle(h : THandle);
         function Open(Mode : Integer) : Boolean;
         function CreateNew : Boolean;
         function CreateTemp(Prefix : String) : Boolean;
         procedure Close;
         procedure CloseFile;

         function  ReadString : String;
         procedure WriteString(S : String);
         procedure WriteDosString(S : String);

         function  ReadInteger : Integer;
         procedure WriteInteger(Val : Integer);

         function  ReadInt64 : Int64;
         procedure WriteInt64(Val : Int64);

         function  ReadLongInt : LongInt;
         procedure WriteLongInt(Val : LongInt);

         function  ReadBoolean : Boolean;
         procedure WriteBoolean(Val : Boolean);

         function  ReadChar : Char;
         procedure WriteChar(Val : Char);

         function  ReadSingle : Single;
         procedure WriteSingle(Val : Single);

         function  ReadDouble : Double;
         procedure WriteDouble(Val : Double);

//         procedure BlockRead(var Buf; Count: Integer);
         function BlockRead2(Buf : Pointer; Count: Integer) : DWord;
//         procedure BlockWrite(var Buf; Count: Integer);
         function BlockWrite2(Buf : Pointer; Count: Integer) : DWord;

//         function EOF : Boolean;
         function FileSize : Int64;

         procedure Seek(Index : Int64);
         function GetPos : Int64;
         function TruncateTo (Length : Int64) : Boolean;

         function GetFileName : String;
         procedure Delete;

         procedure GetCreateTime(t : PFILETIME);
         procedure GetAccessTime(t : PFILETIME);
         procedure GetWriteTime(t : PFILETIME);
         procedure GetFileTimes(ctime : PFILETIME; atime : PFILETIME; mtime : PFILETIME);
         procedure SetFileTimes(ctime : PFILETIME; atime : PFILETIME; mtime : PFILETIME);

         function IsDirectory : Boolean;
   end;
implementation

uses SysUtils, debug;

constructor TBinaryFile.Create;
begin
   IsOpen := False;
end;

destructor TBinaryFile.Destroy;
begin
   if IsOpen then
   begin
      Close;
   end;
end;

procedure TBinaryFile.Assign(Name : String);
begin
   FileName := Name;
end;

procedure TBinaryFile.AssignHandle(h : THandle);
begin
   f := h;
   IsOpen := True;
end;

function TBinaryFile.Open(Mode : Integer) : Boolean;
var
   OpenMode : DWORD;
   ShareMode : DWORD;
begin
   // Mode 0 = read only
   // Mode 1 = read/write

   if IsOpen then
   begin
      Result := True;
      exit;
   end;
   if Mode = OPEN_READ_WRITE then
   begin
      OpenMode := GENERIC_READ or GENERIC_WRITE;
      ShareMode := 0;
   end
   else if Mode = OPEN_WRITE_ONLY then
   begin
      OpenMode := GENERIC_WRITE;
      ShareMode := 0; // ?
   end
   else
   begin
      OpenMode := GENERIC_READ;
      ShareMode := FILE_SHARE_READ;
   end;

   F := CreateFile(PChar(FileName), OpenMode, ShareMode, nil, OPEN_EXISTING, 0, 0);
   if F = INVALID_HANDLE_VALUE then
   begin
      IsOpen := False;
   end
   else
   begin
      IsOpen := True;
   end;
   Result := IsOpen;
end;

function TBinaryFile.CreateNew : Boolean;
begin
   F := CreateFile(PChar(FileName), GENERIC_READ or GENERIC_WRITE, 0, nil, CREATE_NEW, 0, 0);
   if F = INVALID_HANDLE_VALUE then
   begin
      IsOpen := False;
   end
   else
   begin
      IsOpen := True;
   end;
   Result := IsOpen;
end;

function TBinaryFile.CreateTemp(Prefix : String) : Boolean;
var
   TempPath : String;
   L : Integer;
begin
   L := 256;
   SetLength(TempPath, L);
   L := GetTempPath(L, PChar(TempPath));
   SetLength(TempPath, L);

   SetLength(FileName, MAX_PATH);
   GetTempFileName(PChar(TempPath), PChar(Prefix), 0, PChar(FileName));

   // adjust the length...
   SetLength(FileName, StrLen(PChar(FileName)));

   F := CreateFile(PChar(FileName),
               GENERIC_READ or GENERIC_WRITE,
               0,//FILE_SHARE_DELETE or FILE_SHARE_READ,
               nil,
               TRUNCATE_EXISTING,
               0,//FILE_ATTRIBUTE_TEMPORARY or FILE_FLAG_DELETE_ON_CLOSE,
               0);

   if F = INVALID_HANDLE_VALUE then
   begin
      IsOpen := False;
   end
   else
   begin
      IsOpen := True;
   end;
   Result := IsOpen;
end;

procedure TBinaryFile.Close;
begin
   CloseHandle(F);
   IsOpen := False;
end;

procedure TBinaryFile.CloseFile;
begin
   Close;
end;

function TBinaryFile.ReadInteger : Integer;
var
   Actual : DWORD;
begin
   if not IsOpen then
   begin
      Open(0);
   end;
   ReadFile2(F, @Result, SizeOf(Result), Actual, nil);
end;

function TBinaryFile.ReadInt64 : Int64;
var
   Actual : DWORD;
begin
   if not IsOpen then
   begin
      Open(0);
   end;
   ReadFile2(F, @Result, SizeOf(Result), Actual, nil);
end;

function TBinaryFile.ReadLongInt : LongInt;
var
   Actual : DWORD;
begin
   if not IsOpen then
   begin
      Open(0);
   end;
   ReadFile2(F, @Result, SizeOf(Result), Actual, nil);
end;

function TBinaryFile.ReadString : String;
var
   Len    : Integer;
   S      : String;
   Actual : DWORD;
begin
   Len := ReadInteger;
   SetLength(S, Len);
//   System.BlockRead(F, PChar(S)^, Len);
   ReadFile2(F, PChar(S), Len, Actual, nil);
   Result := S;
end;

function  TBinaryFile.ReadChar : Char;
var
   Actual : DWORD;
begin
   if not IsOpen then
   begin
      Open(0);
   end;
   ReadFile2(F, @Result, SizeOf(Result), Actual, nil);
end;

procedure TBinaryFile.WriteChar(Val : Char);
var
   Actual : DWord;
begin
   if not IsOpen then
   begin
      Open(1);
   end;
//   System.BlockWrite(F, Val, SizeOf(Val));
   WriteFile2(F, @Val, SizeOf(Val), Actual, nil);
end;

function  TBinaryFile.ReadSingle : Single;
var
   Actual : DWORD;
begin
   if not IsOpen then
   begin
      Open(0);
   end;
   ReadFile2(F, @Result, SizeOf(Result), Actual, nil);
end;

procedure TBinaryFile.WriteSingle(Val : Single);
var
   Actual : DWORD;
begin
   if not IsOpen then
   begin
      Open(1);
   end;
   WriteFile2(F, @Val, SizeOf(Val), Actual, nil);
end;

function  TBinaryFile.ReadDouble : Double;
var
   Actual : DWORD;
begin
   if not IsOpen then
   begin
      Open(0);
   end;
   ReadFile2(F, @Result, SizeOf(Result), Actual, nil);
end;

procedure TBinaryFile.WriteDouble(Val : Double);
var
   Actual : DWORD;
begin
   if not IsOpen then
   begin
      Open(1);
   end;
   WriteFile2(F, @Val, SizeOf(Val), Actual, nil);
end;

procedure TBinaryFile.WriteInteger(Val : Integer);
var
   Actual : DWord;
begin
   if not IsOpen then
   begin
      Open(1);
   end;
//   System.BlockWrite(F, Val, SizeOf(Val));
   WriteFile2(F, @Val, SizeOf(Val), Actual, nil);
end;

procedure TBinaryFile.WriteInt64(Val : Int64);
var
   Actual : DWord;
begin
   if not IsOpen then
   begin
      Open(1);
   end;
   WriteFile2(F, @Val, SizeOf(Val), Actual, nil);
end;

procedure TBinaryFile.WriteLongInt(Val : LongInt);
var
   Actual : DWord;
begin
   if not IsOpen then
   begin
      Open(1);
   end;
   WriteFile2(F, @Val, SizeOf(Val), Actual, nil);
end;

procedure TBinaryFile.WriteString(S : String);
var
   Actual : DWord;
begin
   WriteInteger(Length(S));
//   System.BlockWrite(F, PChar(S)^, Length(S));
   WriteFile2(F, PChar(S), Length(S), Actual, nil);
end;

procedure TBinaryFile.WriteDosString(S : String);
var
   Actual : DWord;
   CRLF : String;
begin
   CRLF := #13#10;
//   System.BlockWrite(F, PChar(S)^, Length(S));
   WriteFile2(F, PChar(S), Length(S), Actual, nil);
   WriteFile2(F, PChar(CRLF), Length(CRLF), Actual, nil);
end;


function TBinaryFile.BlockRead2(Buf : Pointer; Count: Integer) : DWord;
var
   Actual : DWord;

   RawRead : TRAW_READ_INFO;

   Sector : String;
begin
   if not IsOpen then
   begin
      Open(0);
   end;

// special CD testing

   {SetLength(Sector, RAW_SECTOR_SIZE);
   RawRead.DiskOffset.QuadPart := 0;
   RawRead.SectorCount := 1;
   RawRead.TrackMode := 0;

    if ( DeviceIoControl( F,             $2403E,//CtlCode(IOCTL_CDROM_BASE, $000F, METHOD_OUT_DIRECT, FILE_READ_ACCESS),
                          @RawRead,      sizeof(RawRead),
                          PChar(Sector), Length(Sector),
                          Actual,        nil )) then
      begin
         Log('IOCTL_CDROM_RAW_READ worked');
      end
      else
      begin
         Log('IOCTL_CDROM_RAW_READ failed');
   Log('Error ' + ': ' + IntToStr(Windows.GetLastError) + ' ' + SysErrorMessage(Windows.GetLastError));}
         ReadFile2(F, Buf, Count, Actual, nil);
{         Log('Reading ' + IntToStr(Count) + ' bytes. Actual = ' + intToStr(Actual));
      end;}
   Result := Actual;
end;

function TBinaryFile.BlockWrite2(Buf : Pointer; Count: Integer) : DWORD;
var
   Actual : DWord;
begin
   if not IsOpen then
   begin
      Open(1);
   end;
   WriteFile2(F, Buf, Count, Actual, nil);
   Result := Actual;
end;

function TBinaryFile.FileSize : Int64;
var
   Size : LARGE_INTEGER;
begin
   if not IsOpen then
   begin
      Open(0);
   end;
   Size.LowPart := GetFileSize(F, @Size.HighPart);
   Result := Size.QuadPart;
end;

procedure TBinaryFile.Seek(Index : Int64);
var
   Distance : LARGE_INTEGER;
   R : DWORD;
begin
   Distance.QuadPart := Index;
   R := SetFilePointer(F, Distance.LowPart, @Distance.HighPart, FILE_BEGIN);
   if R = $ffffffff then
   begin
      if GetLastError <> NO_ERROR then
      begin
         //Log('seek error');
      end;
   end;
end;

function TBinaryFile.GetPos : Int64;
var
   Distance : LARGE_INTEGER;
begin
   Distance.QuadPart := 0;
   Distance.LowPart := SetFilePointer(F, Distance.LowPart, @Distance.HighPart, FILE_CURRENT);
   Result := Distance.Quadpart;
end;

function  TBinaryFile.ReadBoolean : Boolean;
begin
   if ReadInteger = 0 then
   begin
      Result := False;
   end
   else
   begin
      Result := True;
   end;
end;

procedure TBinaryFile.WriteBoolean(Val : Boolean);
begin
   if Val then
   begin
      WriteInteger(1);
   end
   else
   begin
      WriteInteger(0);
   end;
end;

function TBinaryFile.TruncateTo (Length : Int64) : Boolean;
begin
   Seek(Length);
   Result := Boolean(SetEndOfFile(F));
end;

function TBinaryFile.GetFileName : String;
begin
   Result := FileName;
end;

procedure TBinaryFile.Delete;
begin
   DeleteFile(FileName);
end;

procedure TBinaryFile.GetCreateTime(t : PFILETIME);
begin
   GetFileTime(F, t, nil, nil);
end;

procedure TBinaryFile.GetAccessTime(t : PFILETIME);
begin
   GetFileTime(F, nil, t, nil);
end;

procedure TBinaryFile.GetWriteTime(t : PFILETIME);
begin
   GetFileTime(F, nil, nil, t);
end;

procedure TBinaryFile.GetFileTimes(ctime : PFILETIME; atime : PFILETIME; mtime : PFILETIME);
begin
   GetFileTime(F, ctime, atime, mtime);
end;

procedure TBinaryFile.SetFileTimes(ctime : PFILETIME; atime : PFILETIME; mtime : PFILETIME);
begin
   SetFileTime(F, ctime, atime, mtime);
end;

function TBinaryFile.IsDirectory : Boolean;
begin
   if (GetFileAttributes(PChar(FileName)) and FILE_ATTRIBUTE_DIRECTORY) > 0 then
   begin
      Result := True;
   end
   else
   begin
      Result := False;
   end;
end;

end.
