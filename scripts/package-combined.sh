#!/bin/bash
# QUEUE=windows:lazarus
# WAIT=true

set -e -u -o pipefail

set -x

. $(dirname $0)/../.buildkite/env.sh

FILE1=ddrelease32.exe
FILE2=ddrelease64.exe
get_artifact $FILE1
get_artifact $FILE2

echo "I should package $FILE1 and $FILE2"

next_step release
