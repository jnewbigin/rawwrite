unit Native;

interface

uses Windows, WinIOCTL, classes;

const

  OBJ_INHERIT =            $00000002;
  OBJ_PERMANENT =          $00000010;
  OBJ_EXCLUSIVE =          $00000020;
  OBJ_CASE_INSENSITIVE =   $00000040;
  OBJ_OPENIF =             $00000080;
  OBJ_OPENLINK =           $00000100;
  OBJ_VALID_ATTRIBUTES =   $000001F2;


  DIRECTORY_QUERY =        $0001;

  /////////////////////////////

  NULL = 0;

  /////////////////////////////

  FILE_READ_DATA =           $0001;    // file & pipe
  FILE_LIST_DIRECTORY =      $0001;    // directory

  FILE_WRITE_DATA =          $0002;    // file & pipe
  FILE_ADD_FILE =            $0002;    // directory

  FILE_APPEND_DATA =         $0004;    // file
  FILE_ADD_SUBDIRECTORY =    $0004;    // directory
  FILE_CREATE_PIPE_INSTANCE =$0004;    // named pipe

  FILE_READ_EA =             $0008;    // file & directory

  FILE_WRITE_EA =            $0010;    // file & directory

  FILE_EXECUTE =             $0020;    // file
  FILE_TRAVERSE =            $0020;    // directory

  FILE_DELETE_CHILD =        $0040;    // directory

  FILE_READ_ATTRIBUTES =     $0080;    // all

  FILE_WRITE_ATTRIBUTES =    $0100;    // all

  FILE_GENERIC_READ =        (STANDARD_RIGHTS_READ     or
                              FILE_READ_DATA           or
                              FILE_READ_ATTRIBUTES     or
                              FILE_READ_EA             or
                              SYNCHRONIZE);


  FILE_GENERIC_WRITE =       (STANDARD_RIGHTS_WRITE    or
                              FILE_WRITE_DATA          or
                              FILE_WRITE_ATTRIBUTES    or
                              FILE_WRITE_EA            or
                              FILE_APPEND_DATA         or
                              SYNCHRONIZE);


  FILE_GENERIC_EXECUTE =     (STANDARD_RIGHTS_EXECUTE  or
                              FILE_READ_ATTRIBUTES     or
                              FILE_EXECUTE             or
                              SYNCHRONIZE);

////////////////////////////

  FILE_SHARE_READ =                $00000001;  // winnt
  FILE_SHARE_WRITE =               $00000002;  // winnt
  FILE_SHARE_DELETE =              $00000004;  // winnt
  FILE_SHARE_VALID_FLAGS =         $00000007;

//////////////////////////////

  FILE_SUPERSEDE =                 $00000000;
  FILE_OPEN =                      $00000001;
  FILE_CREATE =                    $00000002;
  FILE_OPEN_IF =                   $00000003;
  FILE_OVERWRITE =                 $00000004;
  FILE_OVERWRITE_IF =              $00000005;
  FILE_MAXIMUM_DISPOSITION =       $00000005;
/////////////////////////////

  FILE_DIRECTORY_FILE =                    $00000001;
  FILE_WRITE_THROUGH =                     $00000002;
  FILE_SEQUENTIAL_ONLY =                   $00000004;
  FILE_NO_INTERMEDIATE_BUFFERING =         $00000008;

  FILE_SYNCHRONOUS_IO_ALERT =              $00000010;
  FILE_SYNCHRONOUS_IO_NONALERT =           $00000020;
  FILE_NON_DIRECTORY_FILE =                $00000040;
  FILE_CREATE_TREE_CONNECTION =            $00000080;

  FILE_COMPLETE_IF_OPLOCKED =              $00000100;
  FILE_NO_EA_KNOWLEDGE =                   $00000200;
//UNUSED                                        0x00000400
  FILE_RANDOM_ACCESS =                     $00000800;

  FILE_DELETE_ON_CLOSE =                   $00001000;
  FILE_OPEN_BY_FILE_ID =                   $00002000;
  FILE_OPEN_FOR_BACKUP_INTENT =            $00004000;
  FILE_NO_COMPRESSION =                    $00008000;


  FILE_RESERVE_OPFILTER =                  $00100000;
  FILE_TRANSACTED_MODE =                   $00200000;
  FILE_OPEN_OFFLINE_FILE =                 $00400000;

  FILE_VALID_OPTION_FLAGS =                $007fffff;
  FILE_VALID_PIPE_OPTION_FLAGS =           $00000032;
  FILE_VALID_MAILSLOT_OPTION_FLAGS =       $00000032;
  FILE_VALID_SET_FLAGS =                   $00000036;

////////////////////////////
  FILE_WRITE_TO_END_OF_FILE =      $ffffffff;
  FILE_USE_FILE_POINTER_POSITION = $fffffffe;



type

 LONG = LongInt; // I hope!
 ULONG = LongWord; // I hope!
 USHORT = Word;//SmallInt; // I Hope!
 LARGE_NUMBER = Int64;
 PLARGE_NUMBER = ^LARGE_NUMBER;


  NTSTATUS = LONG;
  PHANDLE = ^THANDLE;
  HANDLE = THANDLE;

  PVOID = POINTER;

   UNICODE_STRING = record
    Length : USHORT;
    MaximumLength : USHORT;
    Buffer : PWCHAR;
   end;

   PUNICODE_STRING =^UNICODE_STRING;

  OBJECT_ATTRIBUTES = record
    Length : ULONG;
    RootDirectory : THANDLE;
    ObjectName : PUNICODE_STRING;
    Attributes : ULONG;
    SecurityDescriptor : PVOID;        // Points to type SECURITY_DESCRIPTOR
    SecurityQualityOfService : PVOID;  // Points to type SECURITY_QUALITY_OF_SERVICE
  end;
  POBJECT_ATTRIBUTES = ^OBJECT_ATTRIBUTES;

   IO_STATUS_BLOCK = record
    Status : NTSTATUS;
    Information : ULONG;
   end;
   PIO_STATUS_BLOCK =^IO_STATUS_BLOCK;

   OBJDIR_INFORMATION = record
    ObjectName : UNICODE_STRING;
    ObjectTypeName : UNICODE_STRING ; // e.g. Directory, Device ...
    Data : array of Char;        // variable length
   end;
   POBJDIR_INFORMATION = ^OBJDIR_INFORMATION;


   NtOpenFile_t = function(
				{OUT} FileHandle : PHANDLE;
				{IN} DesiredAccess : ACCESS_MASK;
				{IN} ObjectAttributes : POBJECT_ATTRIBUTES;
				{OUT} IoStatusBlock : PIO_STATUS_BLOCK;
				{IN} ShareAccess : ULONG;
				{IN} OpenOperations : ULONG ) : NTSTATUS; stdcall;

   NtReadFile_t = function(
				{IN} FileEvent : THANDLE;
				{IN} Event : THANDLE; // OPTIONAL
				{IN} ApcRoutine : PVOID {PIO_APC_ROUTINE}; // OPTIONAL
				{IN} ApcContext : PVOID; // OPTIONAL
				{OUT} IoStatusBlock : PIO_STATUS_BLOCK;
				{OUT} Buffer : PVOID;
				{IN} Length : ULONG;
				{IN} {PLARGE_NUMBER} ByteOffset : PLARGE_NUMBER; // OPTIONAL*/
				{IN} Key : PULONG ) : NTSTATUS; stdcall; // OPTIONAL

   RtlNtStatusToDosError_t = function (
		{IN} Status : NTSTATUS) : NTSTATUS; stdcall;

   RtlInitUnicodeString_t = function(
		{IN OUT} DestinationString : PUNICODE_STRING;
		{IN} SourceString : PWCHAR) : NTSTATUS; stdcall;

   NtOpenDirectoryObject_t = function(
		{OUT} DirObjHandle : PHANDLE;
		{IN} DesiredAccess : ACCESS_MASK;
		{IN} ObjectAttributes : POBJECT_ATTRIBUTES ) : NTSTATUS; stdcall;



   NtQueryDirectoryObject_t = function(
		{IN} DirObjHandle : HANDLE;
		{OUT} DirObjInformation : POBJDIR_INFORMATION;
		{IN} BufferLength : ULONG; // size of info buffer
		{IN} GetNextIndex : BOOLEAN;
		{IN} IgnoreInputIndex : BOOLEAN;
		{IN OUT} ObjectIndex : PULONG;
		{OUT} DataWritten : PULONG) : NTSTATUS ; stdcall; // DataWritten can be NULL

   function NativeDir(Dir : WideString; List : TStringList) : Boolean;

var
   NtOpenFile : NtOpenFile_t;
   NtReadFile : NtReadFile_t;
   RtlInitUnicodeString : RtlInitUnicodeString_t;
   RtlNtStatusToDosError : RtlNtStatusToDosError_t;
   NtOpenDirectoryObject : NtOpenDirectoryObject_t;
   NtQueryDirectoryObject : NtQueryDirectoryObject_t;

threadvar
   GetLastError : DWORD;

function Setup : Boolean;

// This is the Win32 function decleration
// Thus, the Native version is compatible with the Win32 code
function NTCreateFile(lpFileName: PChar; dwDesiredAccess, dwShareMode: DWORD;
  lpSecurityAttributes: PSecurityAttributes; dwCreationDisposition, dwFlagsAndAttributes: DWORD;
  hTemplateFile: THandle): THandle;

function NTReadFile2(hFile: THandle; Buffer : Pointer; nNumberOfBytesToRead: DWORD;
    var lpNumberOfBytesRead: DWORD; lpOverlapped: POverlapped): BOOL;

implementation

uses Dialogs, SysUtils, debug;

var
   SetupComplete : Boolean;

function Setup : Boolean;
var
   module_handle : HMODULE;
begin
   if SetupComplete then
   begin
      Result := True;
      exit;
   end;

   Result := False;

	module_handle := GetModuleHandle('ntdll.dll');
   if module_handle = 0 then
   begin
      MessageDlg('Could not find NTDLL.DLL', mtError, [mbOK], 0);
      exit;
   end;

   NtOpenFile := NtOpenFile_t(GetProcAddress( module_handle, 'NtOpenFile' ));

   if not Assigned(NtOpenFile) then
   begin
      MessageDlg('Could not find NtOpenFile entry point in NTDLL.DLL', mtError, [mbOK], 0);
      exit;
   end;

   NtReadFile := NtReadFile_t(GetProcAddress( module_handle, 'NtReadFile' ));

   if not Assigned(NtReadFile) then
   begin
      MessageDlg('Could not find NtReadFile entry point in NTDLL.DLL', mtError, [mbOK], 0);
      exit;
   end;

   RtlNtStatusToDosError := RtlNtStatusToDosError_t(GetProcAddress( module_handle, 'RtlNtStatusToDosError' ));

   if not Assigned(RtlNtStatusToDosError) then
   begin
      MessageDlg('Could not find RtlNtStatusToDosError entry point in NTDLL.DLL', mtError, [mbOK], 0);
      exit;
   end;

   RtlInitUnicodeString := RtlInitUnicodeString_t(GetProcAddress( module_handle, 'RtlInitUnicodeString' ));

   if not Assigned(RtlInitUnicodeString) then
   begin
      MessageDlg('Could not find RtlInitUnicodeString entry point in NTDLL.DLL', mtError, [mbOK], 0);
      exit;
   end;

   NtOpenDirectoryObject := NtOpenDirectoryObject_t(GetProcAddress( module_handle, 'NtOpenDirectoryObject' ));

   if not Assigned(NtOpenDirectoryObject) then
   begin
      MessageDlg('Could not find NtOpenDirectoryObject entry point in NTDLL.DLL', mtError, [mbOK], 0);
      exit;
   end;

   NtQueryDirectoryObject := NtQueryDirectoryObject_t(GetProcAddress( module_handle, 'NtQueryDirectoryObject' ));

   if not Assigned(NtQueryDirectoryObject) then
   begin
      MessageDlg('Could not find NtQueryDirectoryObject entry point in NTDLL.DLL', mtError, [mbOK], 0);
      exit;
   end;

   Result := True;

   SetupComplete := True;
end;

function NT_SUCCESS(Status : NTSTATUS) : Boolean;
begin
   if Status >= 0 then
   begin
      Result := True;
   end
   else
   begin
      Result := False;
   end;
end;


procedure InitializeObjectAttributes(p : POBJECT_ATTRIBUTES;
                                     n : PUNICODE_STRING;
                                     a : ULONG;
                                     r : THANDLE;
                                     s :  PVOID);
begin
   p.Length := sizeof( OBJECT_ATTRIBUTES );
   p.RootDirectory := r;
   p.Attributes := a;
   p.ObjectName := n;
   p.SecurityDescriptor := s;
   p.SecurityQualityOfService := NIL;
end;


function NTCreateFile(lpFileName: PChar; dwDesiredAccess, dwShareMode: DWORD;
  lpSecurityAttributes: PSecurityAttributes; dwCreationDisposition, dwFlagsAndAttributes: DWORD;
  hTemplateFile: THandle): THandle;
var
   UName : UNICODE_STRING;
   FileName : WideString;
   ObjectAttributes : OBJECT_ATTRIBUTES;
	Status : IO_STATUS_BLOCK;
   R : NTSTATUS;
   ErrorNo : DWORD;
begin
   Setup;

   FileName := lpFileName;

   RtlInitUnicodeString(@UName, PWideChar(FileName));

	InitializeObjectAttributes (
						@ObjectAttributes,
						@UName,
						OBJ_CASE_INSENSITIVE,
						NULL,
						NIL);

   R := NtOpenFile(@Result, FILE_GENERIC_READ or SYNCHRONIZE, @ObjectAttributes, @Status, 0, FILE_SYNCHRONOUS_IO_NONALERT{FILE_NON_DIRECTORY_FILE});
{   Debug('Status = 0x' + IntToHex(R, 8), DebugOff);
   Debug('Status.Status = 0x' + IntToHex(Status.Status, 8), DebugOff);
   Debug('Status.Information = 0x' + IntToHex(Status.Information, 8), DebugOff);}

   if not NT_SUCCESS(R) then
   begin
      Result := INVALID_HANDLE_VALUE;
   end;

   ErrorNo := RtlNtStatusToDosError(R);

   SetLastError(ErrorNo);
   GetLastError := ErrorNo;
//   Debug('Win32 Error = (' + IntToStr(GetLastError) + ') ' + SysErrorMessage(GetLastError), DebugOff);

end;

function NTReadFile2(hFile: THandle; Buffer : Pointer; nNumberOfBytesToRead: DWORD;
    var lpNumberOfBytesRead: DWORD; lpOverlapped: POverlapped): BOOL;
var
	Status : IO_STATUS_BLOCK;
   R : NTSTATUS;

   Offset : LARGE_NUMBER;
   ErrorNo : DWORD;

begin
   Offset := 1024;
   R := NtReadFile(hFile, 0, nil, nil, @Status, Buffer, nNumberOfBytesToRead, @Offset, nil);

{   Debug('Status = 0x' + IntToHex(R, 8), DebugOff);
   Debug('Status.Status = 0x' + IntToHex(Status.Status, 8), DebugOff);
   Debug('Status.Information = 0x' + IntToHex(Status.Information, 8), DebugOff);}

   ErrorNo := RtlNtStatusToDosError(R);
   GetLastError := ErrorNo;
//   Debug('Win32 Error = (' + IntToStr(GetLastError) + ') ' + SysErrorMessage(GetLastError), DebugOff);

   if NT_SUCCESS(R) then
   begin
      lpNumberOfBytesRead := Status.Information;
      Result := True;
   end
   else
   begin
      Result := False;
   end;
end;

function NativeDir(Dir : WideString; List : TStringList) : Boolean;
var
   UName             : UNICODE_STRING;
   ObjectAttributes  : OBJECT_ATTRIBUTES;
   Status            : NTSTATUS;
   hObject           : HANDLE;
   index             : ULONG;
   Data              : WideString;
   DirObjInformation : POBJDIR_INFORMATION;
   dw                : ULONG;


begin
   Result := True;
   
   Setup;

   RtlInitUnicodeString(@UName, PWideChar(Dir));

   InitializeObjectAttributes (
						@ObjectAttributes,
						@UName,
						OBJ_CASE_INSENSITIVE,
						0,
						nil);

   Status := NtOpenDirectoryObject(
						@hObject,
						STANDARD_RIGHTS_READ or DIRECTORY_QUERY,
						@ObjectAttributes);

   if(NT_SUCCESS(Status)) then
   begin
	   index := 0; // start index

		while true do
      begin
         SetLength(Data, 1024);
         ZeroMemory(PChar(Data), Length(Data));
			DirObjInformation := POBJDIR_INFORMATION(PChar(Data));
			Status := NtQueryDirectoryObject(
							hObject,
							DirObjInformation,
							Length(Data),
							TRUE,         // get next index
							FALSE,        // don't ignore index input
							@index,
							@dw);         // can be NULL

			if(NT_SUCCESS(Status)) then
         begin
            if Assigned(List) then
            begin
               List.Add(DirObjInformation.ObjectName.Buffer);
            end;
         end
			else if not NT_SUCCESS(Status) then
			begin
//				printf("NtQueryDirectoryObject = 0x%lX (%S)\n", ntStatus, pszDir);
            Result := False;
            break;
			end
   end;

   //NtClose(hObj);
   CloseHandle(hObject);
   end
   else
	begin
{			printf("NtOpenDirectoryObject = 0x%lX (%S)\n", ntStatus,
				  pszDir);}
      Result := False;
  	end
end;


initialization
   SetupComplete := False;

end.
