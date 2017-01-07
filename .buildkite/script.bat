@echo off
REM Do enough to get us into bash
cd "%~dp0"
cd ..
echo starting bash for script %1
"C:\Program Files\Git\bin\bash" "scripts/%1.sh"
