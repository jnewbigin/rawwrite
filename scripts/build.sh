#!/bin/bash
# QUEUE=windows:lazarus

set -e -u -o pipefail

. $(dirname $0)/../.buildkite/env.sh

if [ "$1" == "build" ] ; then
	shift

fi

TARGET=$1
LTARGET=$(echo $TARGET | tr [A-Z] [a-z])
BITS=$2

/c/lazarus/lazbuild.exe --lazarusdir=c:\\lazarus dd.lpi --build-mode=$TARGET

mv dd.exe dd${LTARGET}.exe
put_artifact dd${LTARGET}.exe 

next_step test${BITS}
