#!/bin/bash
# QUEUE=windows:lazarus

set -e -u -o pipefail

set -x

. $(dirname $0)/../.buildkite/env.sh

if [ "$1" == "build" ] ; then
	shift

fi

TARGET=$1
BITS=$2

# CamelCase target
CTARGET=$(echo $TARGET | sed 's|^\([a-z]\)\(.*\)|\u\1\2|g')

# LowerCase target
LTARGET=$(echo $TARGET | sed 's|^\(.*\)|\l\1|g')

/c/lazarus/lazbuild.exe --lazarusdir=c:\\lazarus dd.lpi --build-mode=${CTARGET}${BITS}

mv dd.exe dd${LTARGET}.exe
put_artifact dd${LTARGET}.exe 

next_step test $TARGET ${BITS}
