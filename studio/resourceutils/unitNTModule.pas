(*======================================================================*
 | unitNTModule unit                                                    |
 |                                                                      |
 | Load resources from a module                                         |
 |                                                                      |
 | The contents of this file are subject to the Mozilla Public License  |
 | Version 1.1 (the "License"); you may not use this file except in     |
 | compliance with the License. You may obtain a copy of the License    |
 | at http://www.mozilla.org/MPL/                                       |
 |                                                                      |
 | Software distributed under the License is distributed on an "AS IS"  |
 | basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See  |
 | the License for the specific language governing rights and           |
 | limitations under the License.                                       |
 |                                                                      |
 | Copyright © Colin Wilson 2002.  All Rights Reserved
 |                                                                      |
 | Version  Date        By    Description                               |
 | -------  ----------  ----  ------------------------------------------|
 | 1.0      04/04/2002  CPWW  Original                                  |
 *======================================================================*)

unit unitNTModule;

interface

uses Windows, Classes, SysUtils, unitResourceDetails, ConTnrs;

type

TNTModule = class (TResourceModule)
private
  fDetailList : TObjectList;

  procedure AddResourceToList (AType, AName : PWideChar; ADataLen :  Integer; AData : pointer; ALang : word);
  function LoadResourceFromModule (hModule : Integer; const resType, resName : PChar; language : word) : boolean;
protected
  function GetResourceCount: Integer; override;
  function GetResourceDetails(idx: Integer): TResourceDetails; override;
public
  constructor Create;
  destructor Destroy; override;

  procedure LoadFromFile (const FileName : string); override;
  procedure LoadResources (const fileName : string; tp : PChar);
  function IndexOfResource (details : TResourceDetails) : Integer; override;
end;

implementation

(*----------------------------------------------------------------------------*
 | function EnumResLangProc ()                                                |
 |                                                                            |
 | Callback for EnumResourceLanguages                                         |
 |                                                                            |
 | lParam contains the resource module instance.                              |
 *----------------------------------------------------------------------------*)
function EnumResLangProc (hModule : Integer; resType, resName : PChar; wIDLanguage : word; lParam : Integer) : BOOL; stdcall;
begin
  TNTModule (lParam).LoadResourceFromModule (hModule, resType, resName, wIDLanguage);
  result := True
end;

(*----------------------------------------------------------------------*
 | EnumResNamesProc                                                     |
 |                                                                      |
 | Callback for EnumResourceNames                                       |
 |                                                                      |
 | lParam contains the resource module instance.                        |
 *----------------------------------------------------------------------*)
function EnumResNamesProc (hModule : Integer; resType, resName : PChar; lParam : Integer) : BOOL; stdcall;
begin
  if not EnumResourceLanguages (hModule, resType, resName, @EnumResLangProc, lParam) then
    RaiseLastOSError;
  result := True;
end;

(*----------------------------------------------------------------------*
 | EnumResTypesProc                                                     |
 |                                                                      |
 | Callback for EnumResourceTypes                                       |
 |                                                                      |
 | lParam contains the resource module instance.                        |
 *----------------------------------------------------------------------*)
function EnumResTypesProc (hModule : Integer; resType : PChar; lParam : Integer) : BOOL; stdcall;
begin
  EnumResourceNames (hModule, resType, @EnumResNamesProc, lParam);
  result := True;
end;

{ TNTModule }

const
  rstNotSupported = 'Not supported';

(*----------------------------------------------------------------------*
 | TNTModule.AddResourceToList                                          |
 |                                                                      |
 | Add resource to the resource details list                            |
 *----------------------------------------------------------------------*)
procedure TNTModule.AddResourceToList(AType, AName: PWideChar;
  ADataLen: Integer; AData: pointer; ALang: word);
var
  details : TResourceDetails;

  function ws (ws : PWideChar) : string;
  begin
    if (Integer (ws) and $ffff0000) <> 0 then
      result := ws
    else
      result := IntToStr (Integer (ws))
  end;

begin
  details := TResourceDetails.CreateResourceDetails (self, ALang, ws (AName), ws (AType), ADataLen, AData);
  fDetailList.Add (details);
end;

(*----------------------------------------------------------------------*
 | TNTModule.Create                                                     |
 |                                                                      |
 | Constructor for TNTModule                                            |
 *----------------------------------------------------------------------*)
constructor TNTModule.Create;
begin
  inherited Create;
  fDetailList := TObjectList.Create;
end;

(*----------------------------------------------------------------------*
 | TNTModule.Destroy                                                    |
 |                                                                      |
 | Destructor for TNTModule                                             |
 *----------------------------------------------------------------------*)
destructor TNTModule.Destroy;
begin
  fDetailList.Free;
  inherited;
end;

(*----------------------------------------------------------------------*
 | TNTModule.GetResourceCount                                           |
 |                                                                      |
 | Get method for ResourceCount property                                |
 *----------------------------------------------------------------------*)
function TNTModule.GetResourceCount: Integer;
begin
  result := fDetailList.Count
end;

(*----------------------------------------------------------------------*
 | TNTModule.GetResourceDetails                                         |
 |                                                                      |
 | Get method for resource details property                             |
 *----------------------------------------------------------------------*)
function TNTModule.GetResourceDetails(idx: Integer): TResourceDetails;
begin
  result := TResourceDetails (fDetailList [idx])
end;

(*----------------------------------------------------------------------*
 | TNTModule.IndexOfResource                                            |
 |                                                                      |
 | Find the index for specified resource details                        |
 *----------------------------------------------------------------------*)
function TNTModule.IndexOfResource(details: TResourceDetails): Integer;
begin
  result := fDetailList.IndexOf (details);
end;

(*----------------------------------------------------------------------*
 | TNTModule.LoadFromFile                                               |
 |                                                                      |
 | Load all of a module's resources                                     |
 *----------------------------------------------------------------------*)
procedure TNTModule.LoadFromFile(const FileName: string);
begin
  LoadResources (FileName, Nil);
end;

(*----------------------------------------------------------------------*
 | TNTModule.LoadResourceFromModule                                     |
 |                                                                      |
 | Load a particular resource from a resource handle                    |
 *----------------------------------------------------------------------*)
function TNTModule.LoadResourceFromModule(hModule: Integer; const resType,
  resName: PChar; language: word): boolean;
var
  resourceHandle : Integer;
  infoHandle, size : Integer;
  p : PChar;
  pt, pn : PWideChar;
  wType, wName : WideString;
begin
  result := True;
  resourceHandle := Windows.FindResource (hModule, resName, resType);
  if resourceHandle <> 0 then
  begin
    size := SizeOfResource (hModule, resourceHandle);
    infoHandle := LoadResource (hModule, resourceHandle);
    if infoHandle <> 0 then
    try
      p := LockResource (infoHandle);

      if (Integer (resType) and $ffff0000) = 0 then
        pt := PWideChar (resType)
      else
      begin
        wType := resType;
        pt := PWideChar (wType)
      end;

      if (Integer (resName) and $ffff0000) = 0 then
        pn := PWideChar (resName)
      else
      begin
        wName := resName;
        pn := PWideChar (wName)
      end;

      AddResourceToList (pt, pn, size, p, language);
    finally
      FreeResource (infoHandle)
    end
    else
      RaiseLastOSError;
  end
  else
    RaiseLastOSError;
end;

(*----------------------------------------------------------------------*
 | TNTModule.LoadResources                                              |
 |                                                                      |
 | Load resources of a particular type                                  |
 *----------------------------------------------------------------------*)
procedure TNTModule.LoadResources(const fileName: string; tp: PChar);
var
  Instance : THandle;
begin
  Instance := LoadLibraryEx (PChar (fileName), 0, LOAD_LIBRARY_AS_DATAFILE);
  if Instance <> 0 then
  try
    fDetailList.Clear;
    if tp = Nil then
      EnumResourceTypes (Instance, @EnumResTypesProc, Integer (self))
    else
    begin                           // ... no.  Load specified type...
                                    // ... but if that's an Icon or Cursor group, load
                                    // the icons & cursors, too!

      if tp = RT_GROUP_ICON then
        EnumResourceNames (Instance, RT_ICON, @EnumResNamesProc, Integer (self))
      else
        if tp = RT_GROUP_CURSOR then
          EnumResourceNames (Instance, RT_CURSOR, @EnumResNamesProc, Integer (self));

      EnumResourceNames (Instance, tp, @EnumResNamesProc, Integer (self))
    end
  finally
    FreeLibrary (Instance)
  end
  else
    RaiseLastOSError;
end;

end.
