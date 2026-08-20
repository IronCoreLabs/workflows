#!/bin/bash

# Lists the dotted tags that need to be created so that every undotted major version
# tag has a twin Dependabot can parse. See RELEASING.md and backfill-tags.yaml.
#
# For each tag of the form "NAME-vN" with no existing "NAME-vN.0.0", the new tag name
# and the commit it should point at are printed on stdout, one pair per line. The
# commit is the one the undotted tag already points at, so the twin is a rename rather
# than a release: consumers on an old major become visible to Dependabot, which then
# offers them the current major, without their CI changing under them.
#
# Tags that are already dotted are left alone; they parse as versions as they are.
#
# Must be run from the repo root with all existing tags fetched. The caller is expected
# to create each printed tag and push it.

set -euo pipefail

if [ "$#" -ne 0 ] ; then
    echo "Usage: $0" 1>&2
    exit 1
fi

while IFS= read -r TAG ; do
    [[ "$TAG" =~ -v[0-9]+$ ]] || continue
    NEW="$TAG.0.0"
    if git rev-parse -q --verify "refs/tags/$NEW" > /dev/null ; then
        continue
    fi
    printf '%s %s\n' "$NEW" "$(git rev-parse "$TAG^{commit}")"
done < <(git tag --list '*-v*' | sort)
