#!/bin/bash
# QUEUE=windows:lazarus

set -e -u -o pipefail

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

file dd.exe
mv dd.exe dd${LTARGET}${BITS}.exe
put_artifact dd${LTARGET}${BITS}.exe 

next_step test $TARGET ${BITS}
