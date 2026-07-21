#!/bin/bash

# Lists the floating version tags that need to be created or moved so that every
# reusable workflow's and composite action's declared version tag matches its current
# content. See RELEASING.md and move-tags.yaml for details.
#
# Each reusable workflow and composite action declares its major version in a
# "# tag-version: vN" comment in its yaml file. For each declaration, the tag "NAME-vN"
# is printed on stdout if it doesn't exist, or if the workflow's files (the yaml file
# plus any ".github/NAME.*.sh" helper scripts, or the action's directory) differ
# between the tag and HEAD. Reusable files without a declaration are skipped with a
# warning on stderr; this repo's own CI workflows are skipped silently.
#
# Must be run from the repo root, with HEAD at the commit tags should move to and all
# existing tags fetched. The caller is expected to `git tag -f` and force push each
# printed tag.

set -euo pipefail

if [ "$#" -ne 0 ] ; then
    echo "Usage: $0" 1>&2
    exit 1
fi

# Check one workflow or action. Arguments are its name, the yaml file declaring its
# version, and the pathspecs that make up its content. Prints the tag to move, if any.
check() {
    local name="$1"
    local vfile="$2"
    shift 2

    local version
    version=$(grep -E -o '^# tag-version: v[0-9]+' "$vfile" | head -1 | grep -E -o '[0-9]+$' || true)
    if [ -z "$version" ] ; then
        # Only reusable workflows and actions need a version; this repo's own CI doesn't.
        if [[ "$vfile" == .github/actions/* ]] || grep -q workflow_call "$vfile" ; then
            echo "⚠️  $name: no '# tag-version: vN' comment in $vfile; it will never be released" 1>&2
        fi
        return 0
    fi

    # Never touch a tag older than the newest existing one. That means the comment is
    # stale or was decremented, and moving the old tag would break its consumers.
    local newest=""
    local t n
    while IFS= read -r t ; do
        n="${t#"$name"-v}"
        [[ "$n" =~ ^[0-9]+$ ]] || continue
        if [ -z "$newest" ] || [ "$n" -gt "$newest" ] ; then
            newest="$n"
        fi
    done < <(git tag --list "$name-v*")
    if [ -n "$newest" ] && [ "$newest" -gt "$version" ] ; then
        echo "⚠️  $name: tag $name-v$newest exists but $vfile declares v$version; fix the comment" 1>&2
        return 0
    fi

    local tag="$name-v$version"
    if ! git rev-parse -q --verify "refs/tags/$tag" > /dev/null ; then
        echo "$tag"
    elif ! git diff --quiet "refs/tags/$tag" HEAD -- "$@" ; then
        echo "$tag"
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

check_all | sort
