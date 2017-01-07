@echo off
REM Do enough to get us into bash
cd "%~dp0"
echo starting bash
"C:\Program Files\Git\bin\bash" -x "./%~n0"
