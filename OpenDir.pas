unit OpenDir;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs;


{ SHBrowseForFolder API }

type
{ TSHItemID -- Item ID }

  PSHItemID = ^TSHItemID;
  TSHItemID = packed record           { mkid }
    cb: Word;                         { Size of the ID (including cb itself) }
    abID: array[0..0] of Byte;        { The item ID (variable length) }
  end;

{ TItemIDList -- List if item IDs (combined with 0-terminator) }

  PItemIDList = ^TItemIDList;
  TItemIDList = packed record         { idl }
     mkid: TSHItemID;
   end;
type
  TFNBFFCallBack = function(Wnd: HWND; uMsg: UINT; lParam, lpData: LPARAM): Integer stdcall;

  PBrowseInfoA = ^TBrowseInfoA;
  PBrowseInfoW = ^TBrowseInfoW;
  PBrowseInfo = PBrowseInfoA;
  TBrowseInfoA = packed record
    hwndOwner: HWND;
    pidlRoot: PItemIDList;
    pszDisplayName: PAnsiChar;  { Return display name of item selected. }
    lpszTitle: PAnsiChar;      { text to go in the banner over the tree. }
    ulFlags: UINT;           { Flags that control the return stuff }
    lpfn: TFNBFFCallBack;
    lParam: LPARAM;          { extra info that's passed back in callbacks }
    iImage: Integer;         { output var: where to return the Image index. }
  end;
  TBrowseInfoW = packed record
    hwndOwner: HWND;
    pidlRoot: PItemIDList;
    pszDisplayName: PWideChar;  { Return display name of item selected. }
    lpszTitle: PWideChar;      { text to go in the banner over the tree. }
    ulFlags: UINT;           { Flags that control the return stuff }
    lpfn: TFNBFFCallBack;
    lParam: LPARAM;          { extra info that's passed back in callbacks }
    iImage: Integer;         { output var: where to return the Image index. }
  end;
  TBrowseInfo = TBrowseInfoA;

//////////

  TFlag = (BrowseForComputer, BrowseForPrinter, DontGoBelowDomain,
            ReturnFSAncestors, ReturnOnlyFSDirs, StatusText);

  TFlags = set of TFlag;

const
{ Browsing for directory. }

  BIF_RETURNONLYFSDIRS   = $0001;  { For finding a folder to start document searching }
  BIF_DONTGOBELOWDOMAIN  = $0002;  { For starting the Find Computer }
  BIF_STATUSTEXT         = $0004;
  BIF_RETURNFSANCESTORS  = $0008;

  BIF_BROWSEFORCOMPUTER  = $1000;  { Browsing for Computers. }
  BIF_BROWSEFORPRINTER   = $2000;  { Browsing for Printers }
  BIF_BROWSEINCLUDEFILES = $4000;  { Browsing for Everything }

{ message from browser }

  BFFM_INITIALIZED       = 1;
  BFFM_SELCHANGED        = 2;

{ messages to browser }

  BFFM_SETSTATUSTEXTA         = WM_USER + 100; 
  BFFM_ENABLEOK               = WM_USER + 101; 
  BFFM_SETSELECTIONA          = WM_USER + 102;
  BFFM_SETSELECTIONW          = WM_USER + 103; 
  BFFM_SETSTATUSTEXTW         = WM_USER + 104; 

  BFFM_SETSTATUSTEXT      = BFFM_SETSTATUSTEXTA; 
  BFFM_SETSELECTION       = BFFM_SETSELECTIONA; 

function SHBrowseForFolderA(var lpbi: TBrowseInfoA): PItemIDList; stdcall;
function SHBrowseForFolderW(var lpbi: TBrowseInfoW): PItemIDList; stdcall;
function SHBrowseForFolder(var lpbi: TBrowseInfo): PItemIDList; stdcall;

type
  TOpenDirectory = class(TComponent)
  private
    { Private declarations }
    FTitle : String;
    FFlags : TFlags;
    FDirectory : String;
//    Previous : PItemIDList;

    procedure SetFlags(Flags : TFlags);
    function  GetFlags : TFlags;

    function  GetTitle : String;
    procedure SetTitle(T : String);


  protected
    { Protected declarations }
  public
    { Public declarations }
    constructor Create(AOwner : TComponent); override;
    function Execute : Boolean;
    function Directory : String;
  published
    { Published declarations }
    property Flags : TFlags read GetFlags write SetFlags;
    property Title : String read GetTitle write SetTitle;
  end;

procedure Register;


//function SHBrowseForFolder(BrowseInfo : pBrowseInfo): pITEMIDLIST; stdcall;
function SHGetPathFromIDList(pidl : pITEMIDLIST; pszPath : PChar) : BOOL; stdcall;


implementation

uses ShellAPI;
//const
//  shell32 = 'shell32.dll';

//function SHBrowseForFolder; external shell32 name 'SHBrowseForFolderA';
function SHGetPathFromIDList; external shell32 name 'SHGetPathFromIDListA';

function SHBrowseForFolderA;          external shell32 name 'SHBrowseForFolderA';
function SHBrowseForFolderW;          external shell32 name 'SHBrowseForFolderW';
function SHBrowseForFolder;          external shell32 name 'SHBrowseForFolderA';

procedure Register;
begin
  RegisterComponents('Samples', [TOpenDirectory]);
end;

constructor TOpenDirectory.Create(AOwner : TComponent);
begin
   inherited Create(AOwner);

   FDirectory := '';
   FFlags := [ReturnOnlyFSDirs];
   FTitle := 'Please select a folder';
//   Previous := nil;
end;

procedure TOpenDirectory.SetFlags(Flags : TFlags);
begin
   FFlags := Flags;
end;

function  TOpenDirectory.GetFlags : TFlags;
begin
   Result := FFlags;
end;

function  TOpenDirectory.GetTitle : String;
begin
   Result := FTitle;
end;

procedure TOpenDirectory.SetTitle(T : String);
begin
   FTitle := T;
end;

function TOpenDirectory.Execute : Boolean;
var
   Browse : TBrowseInfo;
   DisplayName : String;
   P : Pointer;

   function AdjustString(S : String) : String;
   var
      i : Integer;
   begin
//      Result := S;
      for i := 1 to Length(S) do
      begin
         if S[i] = #0 then
         begin
//            SetLength(Result, i);
            Result := Copy(S, 1, i - 1);
            break;
         end;
      end;

   end;
begin
   Browse.hWndOwner := Application.MainForm.Handle;
   Browse.pidlRoot := nil;
   SetLength(DisplayName, MAX_PATH);
   Browse.pszDisplayName := PChar(DisplayName);
   Browse.lpszTitle := PChar(FTitle);
   Browse.ulFlags := 0;
   if BrowseForComputer in FFlags then
   begin
      Browse.ulFlags := Browse.ulFlags + BIF_BrowseForComputer;
   end;
   if BrowseForPrinter in FFlags then
   begin
      Browse.ulFlags := Browse.ulFlags + BIF_BrowseForPrinter;
   end;
   if ReturnOnlyFSDirs in FFlags then
   begin
      Browse.ulFlags := Browse.ulFlags + BIF_ReturnOnlyFSDirs;
   end;
   if DontGoBelowDomain in FFlags then
   begin
      Browse.ulFlags := Browse.ulFlags + BIF_DontGoBelowDomain;
   end;
   if ReturnFSAncestors in FFlags then
   begin
      Browse.ulFlags := Browse.ulFlags + BIF_ReturnFSAncestors;
   end;
   if StatusText in FFlags then
   begin
      Browse.ulFlags := Browse.ulFlags + BIF_StatusText;
   end;

   Browse.lpfn := nil;
   Browse.lParam := 0;
   Browse.iImage := 0;
   P := SHBrowseForFolder(Browse);
   if Assigned(P) then
   begin
      SHGetPathFromIDList(P, PChar(DisplayName));
      FDirectory := AdjustString(DisplayName);
      // we have to free P, but I don't know how

      Result := True;
   end
   else
   begin
      Result := False;
   end;
end;

function TOpenDirectory.Directory : String;
begin
   Result := FDirectory;
end;


end.
