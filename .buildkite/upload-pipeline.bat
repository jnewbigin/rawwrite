@echo off
REM Do enough to get us into bash
cd "%~dp0"
dir
echo running "C:\Program Files\Git\git-bash.exe" -c "./%~n0"
"C:\Program Files\Git\bin\bash" -c "./%~n0"
echo done
