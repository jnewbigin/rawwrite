#!/bin/bash
# QUEUE=windows:lazarus

set -e -u -o pipefail

. $(dirname $0)/../.buildkite/env.sh

ENT=${ENT:-/c/tools/ent.exe}

DD=$1

# Basic execution test
echo "This is a test" | $DD

# Random number quality
MSYS_NO_PATHCONV=1 $DD if=/dev/random bs=1M count=10 | $ENT

# Print data only to stdout
echo "This is a test" | $DD 2> /dev/null

# Print human readable only to stderr
echo "Invisible" | $DD > /dev/null

# test exit code...

# test random read

# test short read

# test block device mapping - if possible

# test block device reading

# test block device writing

