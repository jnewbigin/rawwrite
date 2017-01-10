#!/bin/bash
# QUEUE=windows:lazarus

set -e -u -o pipefail

. $(dirname $0)/../.buildkite/env.sh

APP_VERSION=$(grep 'const AppVersion' studio/studio_tools.pas | cut -d "'" -f 2)

BITS="32 64"

echo "Building dd version $APP_VERSION for $BITS"

set_metadata version "$APP_VERSION"

for BIT in $BITS ; do
	next_step build debug $BIT
done

