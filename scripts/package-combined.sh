#!/bin/bash
# QUEUE=windows:lazarus

set -e -u -o pipefail

. $(dirname $0)/../.buildkite/env.sh

VERSION=$(get_metadata version)
BITS=$(get_metadata bits)

set +e

for BIT in $BITS ; do
	FILENAME=ddrelease${BIT}.exe
	( set +e ; get_artifact $FILENAME )
	if [ ! -f "$FILENAME" ] ; then
		echo "Artifact $FILENAME is not ready yet"
		exit 0
	fi
done

echo "I should package $BITS as $VERSION"
next_step publish
