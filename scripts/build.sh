#!/bin/bash
# QUEUE=windows:lazarus

set -e -u -o pipefail

. $(dirname $0)/../.buildkite/env.sh

set -x

#/c/lazarus/fpc/3.0.0/bin/i386-win32/ppcrossx64.exe  -Twin64 -Px86_64 -MDelphi -Scaghi -CirotR -O1 -gw2 -godwarfsets -gl -gh -Xg -gt -l -vewnhibq -Fistudio -Fistudio\\md5 -Fistudio\\random -Fustudio -Fustudio\\md5 -Fustudio\\random -FuC:\\lazarus\\lcl\\units\\x86_64-win64\\win32 -FuC:\\lazarus\\lcl\\units\\x86_64-win64 -FuC:\\lazarus\\components\\lazutils\\lib\\x86_64-win64 -FuC:\\lazarus\\packager\\units\\x86_64-win64 -Fu. -dLCL -dLCLwin32 -dBorland -dVer150 -dDelphi7 -dCompiler6_Up -dPUREPASCAL dd.lpr

/c/lazarus/lazbuild.exe --lazarusdir=c:\\lazarus dd.lpi

