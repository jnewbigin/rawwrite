#!/bin/bash
# QUEUE=windows:lazarus

set -e -u -o pipefail

set -x

. $(dirname $0)/../.buildkite/env.sh

if [ "$1" == "package" ] ; then
	shift
fi

TARGET=$1
BITS=$2

FILE=dd${TARGET}${BITS}.exe
get_artifact $FILE

echo "I should package $FILE"

