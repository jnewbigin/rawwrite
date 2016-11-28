unit UnixBinFile;
// $Header: /home/cso/jnewbigin/cvsroot/rawwrite/UnixBinFile.pas,v 1.1 2005/12/05 08:26:02 jnewbigin Exp $

{$IFDEF FPC}
{$MODE Delphi}
{$ENDIF}

interface

uses BaseUnix;

const OPEN_READ_ONLY = 0;
const OPEN_READ_WRITE = 1;
const OPEN_WRITE_ONLY = 2;

procedure CopyMemory(Destination : PChar; Source : PChar; Length : DWORD);
procedure FillMemory(Buffer : PChar; Length : DWORD; Value : ShortInt);

type
   TBinaryFile = class
      private
         FileName : String;
         F        : cInt;
         IsOpen   : Boolean;
      public
         constructor Create;
         destructor Destroy; override;

         procedure Assign(Name : String);
         procedure AssignHandle(h : cInt);
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
{
         procedure GetCreateTime(t : PFILETIME);
         procedure GetAccessTime(t : PFILETIME);
         procedure GetWriteTime(t : PFILETIME);
         procedure GetFileTimes(ctime : PFILETIME; atime : PFILETIME; mtime : PFILETIME);
         procedure SetFileTimes(ctime : PFILETIME; atime : PFILETIME; mtime : PFILETIME);
}
         function IsDirectory : Boolean;
   end;
implementation

uses SysUtils;

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
   OpenMode : TMode;
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
      OpenMode := O_RdWr;
   end
   else if Mode = OPEN_WRITE_ONLY then
   begin
      OpenMode := O_WrOnly;
   end
   else
   begin
      OpenMode := O_RdOnly;
   end;

   F := FpOpen(FileName, OpenMode);
   if F = 0 then
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
   F := FpOpen(FileName, O_RdWr or O_Creat);
   if F = 0 then
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
{
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
   Result := IsOpen;}
end;

procedure TBinaryFile.Close;
begin
   FpClose(F);
   IsOpen := False;
end;

procedure TBinaryFile.CloseFile;
begin
   Close;
end;

function ReadFile2(hFile: cInt; Buffer : pChar; nNumberOfBytesToRead: TSize;
    var lpNumberOfBytesRead: TSize; lpOverlapped: pointer): BOOLEAN;
begin
   lpNumberOfBytesRead := FpRead(hFile, Buffer, nNumberOfBytesToRead);
   Result := lpNumberOfBytesRead = nNumberOfBytesToRead;
end;

function WriteFile2(hFile: cInt; Buffer : pChar; nNumberOfBytesToWrite: TSize;
    var lpNumberOfBytesWritten: TSize; lpOverlapped: pointer): BOOLEAN;
begin
   lpNumberOfBytesWritten := FpWrite(hFile, Buffer, nNumberOfBytesToWrite);
   Result := lpNumberOfBytesWritten = nNumberOfBytesToWrite;
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
begin
   if not IsOpen then
   begin
      Open(0);
   end;
   ReadFile2(F, Buf, Count, Actual, nil);
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
   info : stat;
begin
   if not IsOpen then
   begin
      Open(0);
   end;
   FpFstat(F, info);
   Result := info.st_size;
end;

procedure TBinaryFile.Seek(Index : Int64);
begin
   FpLseek(F, Index, Seek_Set);
end;

function TBinaryFile.GetPos : Int64;
begin
   Result := FpLseek(F, 0, Seek_Cur);
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
   Result := FpFtruncate(F, Length) = 0;
end;

function TBinaryFile.GetFileName : String;
begin
   Result := FileName;
end;

procedure TBinaryFile.Delete;
begin
   DeleteFile(FileName);
end;

{
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
}
function TBinaryFile.IsDirectory : Boolean;
var
   info : stat;
begin
   FpStat(FileName, info);
   Result := FpS_ISDIR(info.st_mode);
end;

procedure CopyMemory(Destination : PChar; Source : PChar; Length : DWORD);
var
   i : DWORD;
begin
   for i := 0 to Length - 1 do
   begin
      Destination[i] := Source[i];
   end;
end;

procedure FillMemory(Buffer : PChar; Length : DWORD; Value : ShortInt);
var
   i : DWORD;
begin
   for i := 0 to Length - 1 do
   begin
      Buffer[i] := Chr(Value);
   end;
end;

end.
