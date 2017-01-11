#!/bin/bash
# QUEUE=windows:lazarus

set -e -u -o pipefail

. $(dirname $0)/../.buildkite/env.sh

set +e
FILE1=ddrelease32.exe
FILE2=ddrelease64.exe
get_artifact $FILE1
get_artifact $FILE2

if [ -f "$FILE1" -a -f "$FILE2" ] ; then
	echo "I should package $FILE1 and $FILE2"
	next_step publish
else
	echo "Not all the artifacts are ready yet"
fi
