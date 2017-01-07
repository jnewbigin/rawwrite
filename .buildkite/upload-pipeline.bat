@echo off
REM Do enough to get us into bash
echo %0
echo %~0
echo %n0
echo %x0
echo %~n0
echo %dp0
echo %~dp0
echo running "C:\Program Files\Git\git-bash.exe" --cd-to-home -x -c "cd %~dp0 ; ./%~n0"
"C:\Program Files\Git\git-bash.exe" --cd-to-home -x -c "cd %~dp0 ; ./%~n0"
echo done
