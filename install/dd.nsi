!include "MUI.nsh"
!include LogicLib.nsh
!include x64.nsh
!include WinVer.nsh

!define PRODUCT_NAME "Chrysocome dd for Windows"
!define PRODUCT_VER_MAJ "1"
!define PRODUCT_VER_MIN "0"
!define PRODUCT_VER "${PRODUCT_VER_MAJ}.${PRODUCT_VER_MIN}"

Name "${PRODUCT_NAME} ${PRODUCT_VER}"
OutFile "dd-${PRODUCT_VER}-install.exe"

InstallDir "$PROGRAMFILES\Chrysocome"

SetCompressor /SOLID lzma
#!finalize '"C:\apps\WinDDK\7600.16385.1\bin\x86\SignTool.exe" sign /v /s PrivateCertStore /n chrysocome.net(Test) "%1"'

VIProductVersion "${PRODUCT_VER}.0.0"
VIAddVersionKey /LANG=${LANG_ENGLISH} "ProductName" "${PRODUCT_NAME}"
;VIAddVersionKey /LANG=${LANG_ENGLISH} "Comments" ""
VIAddVersionKey /LANG=${LANG_ENGLISH} "CompanyName" "Chrysocome"
;VIAddVersionKey /LANG=${LANG_ENGLISH} "LegalTrademarks" ""
VIAddVersionKey /LANG=${LANG_ENGLISH} "LegalCopyright" "John Newbigin. GPL"
VIAddVersionKey /LANG=${LANG_ENGLISH} "FileDescription" "${PRODUCT_NAME} Installer"
VIAddVersionKey /LANG=${LANG_ENGLISH} "FileVersion" "${PRODUCT_VER}.0.0"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "..\Copying.txt"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "English"


Section "Main Program Files" SecMain
	SetOutPath $INSTDIR
	File "..\artifacts\dd.exe"
	File "..\ddchanges.txt"

	WriteUninstaller "$INSTDIR\Uninstall.exe"

	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "DisplayName"	"${PRODUCT_NAME}"
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "UninstallString" "$INSTDIR\Uninstall.exe"
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "Publisher" 	"Chrysocome"
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "DisplayVersion" "${PRODUCT_VER}"
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "VersionMajor" 	"${PRODUCT_VER_MAJ}"
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "VersionMinor" 	"${PRODUCT_VER_MIN}"
	WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "NoModify" 	1
	WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "NoRepair" 	1

SectionEnd

Section "Add dd to path" SecPath
	; no files in this section
SectionEnd

Section -post
	
  SectionGetFlags ${SecPath} $R0
  IntOp $R0 $R0 & 1
  IntCmp $R0 1 "" nopath nopath

  DetailPrint "Altering path"
  #nsExec::ExecToLog '... "$INSTDIR'

 nopath:

SectionEnd

Section "Uninstall"
	Delete "$INSTDIR\Uninstall.exe"
	Delete "$INSTDIR\readme.txt"
	Delete "$INSTDIR\ddchanges.txt"
	Delete "$INSTDIR\dd.exe"
	RMDir "$INSTDIR"

	DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"

	# nsExec::ExecToLog 'remove path "$INSTDIR"'

SectionEnd

  LangString DESC_SecMain      ${LANG_ENGLISH} "Install Main Program Files."
  LangString DESC_SecPath      ${LANG_ENGLISH} "Add dd to the default windows path."

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecMain} $(DESC_SecMain)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecPath} $(DESC_SecPath)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Function .onInit
start:
  ReadRegStr $R0 HKLM \
  "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" \
  "UninstallString"
  StrCmp $R0 "" done
 
  MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION \
  "${PRODUCT_NAME} is already installed. $\n$\nClick `OK` to remove the \
  previous version or `Cancel` to cancel this upgrade." \
  IDOK uninst
  Abort


  ; Windows Version check for Dokan

;Run the uninstaller
uninst:
  ClearErrors
  ExecWait '$R0 _?=$INSTDIR' ;Do not copy the uninstaller to a temp file
 
  IfErrors no_remove_uninstaller
    ;You can either use Delete /REBOOTOK in the uninstaller or add some code
    ;here to remove the uninstaller. Use a registry key to check
    ;whether the user has chosen to uninstall. If you are using an uninstaller
    ;components page, make sure all sections are uninstalled.
  no_remove_uninstaller:

  goto start
  
done:
 
FunctionEnd


