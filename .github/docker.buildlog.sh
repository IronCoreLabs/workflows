#!/bin/bash

# Update the buildlog with information about a particular container build.

set -e

if [ $# -ne 3 ] ; then
    echo "Usage: $0 <buildlog-file> <version> <container-hash>" 1>&2
    exit 1
fi
LOG_FILE="$1"
VERSION="$2"
IMAGE_HASH="$3"

GIT_HASH="$(git rev-parse HEAD)"
WORKDIR=.github/tmp_buildlog_dir
cd "${WORKDIR}"
TEMPDIR="$(mktemp -d)"

ATTEMPTS=0
MAX_ATTEMPTS=10
while [ "${ATTEMPTS}" -lt "${MAX_ATTEMPTS}" ] ; do
    ATTEMPTS=$((ATTEMPTS + 1))

    # The log file is a JSON array. If it doesn't exist, create an empty array.
    if ! [ -f "${LOG_FILE}" ] ; then
        echo "[]" > "${LOG_FILE}"
    fi

    # Add our new buildlog entry.
    jq \
        --arg date "$(date +%Y-%m-%d)" \
        --arg version "${VERSION}" \
        --arg git_hash "${GIT_HASH}" \
        --arg image_hash "${IMAGE_HASH}" \
        '. + [{"date": $date, "version": $version, "container_hash": $image_hash, "git_hash": $git_hash}]' \
        < "${LOG_FILE}" > "${LOG_FILE}.new"
    mv "${LOG_FILE}.new" "${LOG_FILE}"

    git add "${LOG_FILE}"
    git commit -m "buildlog: ${LOG_FILE} ${VERSION}"

    if ! git push --porcelain > "${TEMPDIR}/push-output" ; then
        if grep -q rejected "${TEMPDIR}/push-output" ; then
            # Remote rejected our push, probably due to concurrent modification by another instance of this script running on
            # another version. We want to try again by falling through to the end of the big while loop.

            # Clobber our last commit and pull the latest from origin.
            git reset --hard HEAD~1
            git pull
        else
            # Some other git error. Abort the script.
            cat "${TEMPDIR}/push-output"
            exit 1
        fi
    else
        # Git push was successful. Exit.
        exit 0
    fi
done
# We exited the loop after failing to update multiple times.
exit 1
