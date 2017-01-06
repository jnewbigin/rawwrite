#!/bin/bash

set -e -u -o pipefail

. $(dirname $0)/../.buildkite/env.sh

set -x

echo "Hello"

which fpc
