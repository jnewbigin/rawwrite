# Environment for buildkite scripts

# Make scripts fail all the time, to keep you on your toes
set -eo pipefail

DIR=$(dirname "$(readlink -f "$0")")/..

# Tell buildkite which step to run next
function next_step()
{
	if [ "$BUILDKITE_AGENT_ACCESS_TOKEN" ] ; then
	if [ -f "${DIR}/.buildkite/pipeline-${1}.yml" ] ; then
		echo "Activating pipeline ${1}"
		buildkite-agent pipeline upload < ${DIR}/.buildkite/pipeline-${1}.yml
	elif [ -f "${DIR}/scripts/${1}.sh" ] ; then
		echo "Generating pipeline for ${1}"
		QUEUE=$((grep '^# QUEUE=' "${DIR}/scripts/${1}.sh" || true) | cut -d = -f 2)
		NAME=$((grep '^# NAME=' "${DIR}/scripts/${1}.sh" || true) | cut -d = -f 2-)
		if [ -z "$QUEUE" ] ; then
			# Should we default to what this is currenly running on?
			QUEUE=default
		fi
		if [ -z "$NAME" ] ; then
			NAME="${1}"
		fi
		SCRIPT=".buildkite/script.bat ${1} ${2}"
		# grep and see if there is a QUEUE tag in the script
		# We should also check if there is a .buildkite/docker-compose.yml file
		cat << END | buildkite-agent pipeline upload
---
steps:
        - name: '${NAME}'
          command: '${SCRIPT}'
          agents:
                  queue: '${QUEUE}'
END
	else
		echo "No pipeline step '${1}'"
		exit 1
	fi
	else
		echo "Next step -> scripts/${1}.sh"
	fi
}

echo "--- build environment"
echo DIR=$DIR
echo PWD=`pwd`
set

# Make a short version of $BUILDKITE_MESSAGE
SHORT_MESSAGE=$(echo "$BUILDKITE_MESSAGE" | head -1)

echo "+++ build output"


