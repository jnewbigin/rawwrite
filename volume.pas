unit volume;

interface

uses Windows, sysutils;

const
  kernel32  = 'kernel32.dll';

type
   TFindFirstVolume = function (lpszVolumeName : PAnsiChar; cchBufferLength : DWORD): THANDLE; stdcall;
   TFindNextVolume = function (hFindVolume : THANDLE; lpszVolumeName : PAnsiChar; cchBufferLength : DWORD): BOOL; stdcall;
   TFindVolumeClose = function (hFindVolume : THANDLE): BOOL; stdcall;

   TFindFirstVolumeMountPoint = function (lpszRootPathName : PAnsiChar; lpszVolumeMountPoint : PAnsiChar; cchBufferLength : DWORD): THANDLE; stdcall;
   TFindNextVolumeMountPoint = function (hFindVolumeMountPoint : THANDLE; lpszVolumeMountPoint : PAnsiChar; cchBufferLength : DWORD): BOOL; stdcall;
   TFindVolumeMountPointClose = function (hFindVolumeMountPoint : THANDLE): BOOL; stdcall;

   TGetVolumeNameForVolumeMountPoint = function (lpszVolumeMountPoint : PAnsiChar; lpszVolumeName : PAnsiChar; cchBufferLength : DWORD): BOOL; stdcall;

   TDeleteVolumeMountPoint = function (lpszVolumeMountPoint : PAnsiChar) : BOOL; stdcall;
   TSetVolumeMountPoint = function (lpszVolumeMountPoint : PAnsiChar; lpszVolumeName : PAnsiChar) : BOOL; stdcall;

   procedure LoadVolume;
var
   JFindFirstVolume : TFindFirstVolume;
   JFindNextVolume  : TFindNextVolume;
   JFindVolumeClose : TFindVolumeClose;

   JFindFirstVolumeMountPoint : TFindFirstVolumeMountPoint;
   JFindNextVolumeMountPoint  : TFindNextVolumeMountPoint;
   JFindVolumeMountPointClose : TFindVolumeMountPointClose;

   JGetVolumeNameForVolumeMountPoint : TGetVolumeNameForVolumeMountPoint;

   JDeleteVolumeMountPoint : TDeleteVolumeMountPoint;
   JSetVolumeMountPoint    : TSetVolumeMountPoint;

implementation
var
   VolumeLoaded : Boolean = False;


procedure LoadVolume;
var
   hModule : hInst;
   Error : DWORD;

   function GetAddress(ProcName : PChar) : Pointer;
   begin
      Result := GetProcAddress(hModule, ProcName);
      if Result = nil then
      begin
         raise Exception.Create('Could not find procedure ' + ProcName);
      end;
   end;
begin
   if VolumeLoaded then exit;

   // Load WinINET...
   hModule := GetModuleHandle(kernel32);
   if hModule = 0 then
   begin
      //   kernel32 is not yet loaded... (unlkely but...)
      hModule := LoadLibrary(kernel32);
      if hModule = 0 then
      begin
         Error := GetLastError;
         raise Exception.Create('Error loading kernel32 Library.  ' + SysErrorMessage(Error));
      end;
   end;

   // by here we have an hModule or have raised an exception
   // Map the function addresses...
   JFindFirstVolume := GetAddress('FindFirstVolumeA');
   JFindNextVolume  := GetAddress('FindNextVolumeA');
   JFindVolumeClose := GetAddress('FindVolumeClose');

   JFindFirstVolumeMountPoint := GetAddress('FindFirstVolumeMountPointA');
   JFindNextVolumeMountPoint  := GetAddress('FindNextVolumeMountPointA');
   JFindVolumeMountPointClose := GetAddress('FindVolumeMountPointClose');

   JGetVolumeNameForVolumeMountPoint := GetAddress('GetVolumeNameForVolumeMountPointA');

   JDeleteVolumeMountPoint := GetAddress('DeleteVolumeMountPointA');
   JSetVolumeMountPoint    := GetAddress('SetVolumeMountPointA');

   VolumeLoaded := True;
end;

end.
