@echo off
if "%COMPUTERNAME%" == "JNEWBIGIN-HPC" goto home

:work
echo Using work config
set UPXPATH=c:\apps\upx\upx
set ZIPPATH=c:\apps\info-zip\zip

goto cont

:home
echo Using home config
set UPXPATH=f:\apps\upx\upx
set ZIPPATH=f:\apps\info-zip\zip

goto cont

:cont
%UPXPATH% -9 rawwritewin.exe

..\infoin2\client\reconfig\reconfig --dfm=rawwrite.dfm
call autoversion
set VERSION=%AUTO_VERSION%
set ZIPNAME=rawwritewin-%VERSION%.zip
echo %ZIPNAME%
del %ZIPNAME%
%ZIPPATH% %ZIPNAME% rawwritewin.exe diskio.dll readme.txt changes.txt
echo Copying to uranus
copy %ZIPNAME% \\uranus\html\linux\%ZIPNAME%

rem zip the source code...
set ZIPNAME=rawwritewin-%VERSION%.src.zip
del %ZIPNAME%
%ZIPPATH% %ZIPNAME% *.pas *.dfm diskio.dll readme.txt changes.txt floppy.bmp Icon3.ico rawwritewin.dpr
echo Copying to uranus
copy %ZIPNAME% \\uranus\html\linux\%ZIPNAME%

rem Set up the autoupgrade
echo Copying to uranus
copy rawwritewin.exe \\uranus\itig\autoupgrade\rawwrite\rawwritewin.exe
echo %AUTO_VERSION_NO% > \\uranus\itig\autoupgrade\rawwrite\VERSION
copy ..\autoupdate\autohelp.exe \\uranus\itig\autoupgrade\rawwrite\autohelp.exe

pause
