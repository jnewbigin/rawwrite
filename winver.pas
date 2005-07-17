unit winver;

interface

uses Windows;

const VER_SERVER_NT                      = $80000000;
const VER_WORKSTATION_NT                 = $40000000;
const VER_SUITE_SMALLBUSINESS            = $00000001;
const VER_SUITE_ENTERPRISE               = $00000002;
const VER_SUITE_BACKOFFICE               = $00000004;
const VER_SUITE_COMMUNICATIONS           = $00000008;
const VER_SUITE_TERMINAL                 = $00000010;
const VER_SUITE_SMALLBUSINESS_RESTRICTED = $00000020;
const VER_SUITE_EMBEDDEDNT               = $00000040;
const VER_SUITE_DATACENTER               = $00000080;
const VER_SUITE_SINGLEUSERTS             = $00000100;
const VER_SUITE_PERSONAL                 = $00000200;
const VER_SUITE_BLADE                    = $00000400;
const VER_SUITE_EMBEDDED_RESTRICTED      = $00000800;
const VER_SUITE_SECURITY_APPLIANCE       = $00001000;

const VER_NT_WORKSTATION             = $0000001;
const VER_NT_DOMAIN_CONTROLLER       = $0000002;
const VER_NT_SERVER                  = $0000003;


type
  _OSVERSIONINFOEXA = record
    dwOSVersionInfoSize: DWORD;
    dwMajorVersion: DWORD;
    dwMinorVersion: DWORD;
    dwBuildNumber: DWORD;
    dwPlatformId: DWORD;
    szCSDVersion: array[0..127] of AnsiChar; { Maintenance string for PSS usage }
    wServicePackMajor : WORD;
    wServicePackMinor : WORD;
    wSuiteMask : WORD;
    wProductType : BYTE;
    wReserved : BYTE;
  end;
  TOSVersionInfoExA = _OSVERSIONINFOEXA;
  TOSVersionInfoEx = TOSVersionInfoExA;

function GetVersionEx2(var lpVersionInformation: TOSVersionInfoEx): BOOL; stdcall;

function MaskBitSet(Mask : WORD; Bit : WORD) : Boolean;

implementation

function GetVersionEx2; external kernel32 name 'GetVersionExA';

function MaskBitSet(Mask : WORD; Bit : WORD) : Boolean;
begin
   if (Mask AND Bit) = Bit then
   begin
      Result := True;
   end
   else
   begin
      Result := False;
   end;
end;

end.
