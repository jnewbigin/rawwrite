#!/bin/bash
# QUEUE=windows:lazarus

set -e -u -o pipefail

set -x

. $(dirname $0)/../.buildkite/env.sh

APP_VERSION=$(grep 'const AppVersion' studio/studio_tools.pas | cut -d "'" -f 2)

set_metadata version "$APP_VERSION"

next_step build debug 32
next_step build debug 64

