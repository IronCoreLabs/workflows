#!/bin/bash

# Lists the floating version tags that need to be created or moved so that every
# reusable workflow's and composite action's declared version tag matches its current
# content. See RELEASING.md and move-tags.yaml for details.
#
# Each reusable workflow and composite action declares its major version in a
# "# tag-version: vN" comment in its yaml file. For each declaration, the tag
# "NAME-vN.0.0" is printed on stdout if it doesn't exist, or if the workflow's files
# (the yaml file plus any ".github/NAME.*.sh" helper scripts, or the action's
# directory) differ between the tag and HEAD.
#
# A reusable workflow or action without a usable declaration is a misconfiguration:
# it's reported on stderr and the script exits nonzero, after checking everything.
# This repo's own CI workflows don't need declarations and are skipped silently.
#
# Must be run from the repo root, with HEAD at the commit tags should move to and all
# existing tags fetched. The caller is expected to `git tag -f` and force push each
# printed tag.

set -euo pipefail

if [ "$#" -ne 0 ] ; then
    echo "Usage: $0" 1>&2
    exit 1
fi

TAGS=()
ERRORS=0

# Check one workflow or action. Arguments are its name, the yaml file declaring its
# version, and the pathspecs that make up its content. Appends to TAGS and sets ERRORS.
check() {
    local name="$1"
    local vfile="$2"
    shift 2

    local version
    version=$(grep -E -o '^# tag-version: v[0-9]+' "$vfile" | head -1 | grep -E -o '[0-9]+$' || true)
    if [ -z "$version" ] ; then
        # Only reusable workflows and actions need a version; this repo's own CI doesn't.
        if [[ "$vfile" == .github/actions/* ]] || grep -q workflow_call "$vfile" ; then
            echo "❌ $name: no '# tag-version: vN' comment in $vfile; it will never be released" 1>&2
            ERRORS=1
        fi
        return 0
    fi

    # The parse above stops at the first dot, so a dotted declaration would be silently
    # truncated to its major, discarding whatever the author meant by the rest. Since
    # the tags are dotted, that's an easy comment to write by mistake.
    if grep -qE '^# tag-version: v[0-9]+\.' "$vfile" ; then
        echo "$name: $vfile declares a dotted version; the comment carries the major only, as 'v$version'" 1>&2
        ERRORS=1
        return 0
    fi

    # Never touch a tag older than the newest existing one. That means the comment is
    # stale or was decremented, and moving the old tag would break its consumers.
    local newest=""
    local t n
    while IFS= read -r t ; do
        n="${t#"$name"-v}"
        n="${n%%.*}"
        [[ "$n" =~ ^[0-9]+$ ]] || continue
        if [ -z "$newest" ] || [ "$n" -gt "$newest" ] ; then
            newest="$n"
        fi
    done < <(git tag --list "$name-v*")
    if [ -n "$newest" ] && [ "$newest" -gt "$version" ] ; then
        echo "❌ $name: tag $name-v$newest exists but $vfile declares v$version; fix the comment" 1>&2
        ERRORS=1
        return 0
    fi

    # Dotted because Dependabot only recognizes a bare "vN" ref when the "v" starts it:
    # a prefixed "$name-v$version" is invisible to it, so consumers pinned to that name
    # never get upgrade PRs. The tag still floats; the digits are for the parser only.
    local tag="$name-v$version.0.0"
    if ! git rev-parse -q --verify "refs/tags/$tag" > /dev/null ; then
        TAGS+=("$tag")
    elif ! git diff --quiet "refs/tags/$tag" HEAD -- "$@" ; then
        TAGS+=("$tag")
    fi
}

check_all() {
    local f d base name vfile
    for f in .github/workflows/*.yaml .github/workflows/*.yml ; do
        [ -f "$f" ] || continue
        base=$(basename "$f")
        name="${base%.*}"
        check "$name" "$f" "$f" ".github/$name.*.sh"
    done
    for d in .github/actions/*/ ; do
        [ -d "$d" ] || continue
        name=$(basename "$d")
        vfile=""
        for f in "$d"action.yaml "$d"action.yml ; do
            [ -f "$f" ] && vfile="$f"
        done
        [ -z "$vfile" ] && continue
        check "$name" "$vfile" "$d"
    done
}

check_all
if [ "${#TAGS[@]}" -gt 0 ] ; then
    printf '%s\n' "${TAGS[@]}" | sort
fi
exit "$ERRORS"
