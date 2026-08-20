Describe 'backfill-tags.list.sh'
    SCRIPT="$PWD/backfill-tags.list.sh"

    cleanup() {
        if [ -n "${SANDBOX:-}" ] ; then
            cd /
            rm -rf "$SANDBOX"
        fi
    }
    After 'cleanup'

    # Create a sandbox git repo with one commit to hang tags off.
    setup_repo() {
        SANDBOX=$(mktemp -d)
        cd "$SANDBOX" || return 1
        export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
            GIT_AUTHOR_NAME=spec GIT_AUTHOR_EMAIL=spec@example.com \
            GIT_COMMITTER_NAME=spec GIT_COMMITTER_EMAIL=spec@example.com
        git init -q -b main .
        commit
    }

    commit() {
        printf '%s\n' "${1:-content}" > file.txt
        git add -A .
        git commit -q -m 'commit'
    }

    undotted_tag() {
        setup_repo
        git tag foo-v1
        "$SCRIPT" | cut -d' ' -f1
    }
    It 'names a twin for an undotted tag'
        When call undotted_tag
        The output should equal 'foo-v1.0.0'
        The status should be success
    End

    twin_exists() {
        setup_repo
        git tag foo-v1
        git tag foo-v1.0.0
        "$SCRIPT"
    }
    It 'is quiet when the twin already exists'
        When call twin_exists
        The output should equal ''
        The status should be success
    End

    already_dotted() {
        setup_repo
        git tag foo-v0.1
        git tag foo-v2.0.0
        "$SCRIPT"
    }
    It 'leaves tags that are already dotted alone'
        When call already_dotted
        The output should equal ''
        The status should be success
    End

    non_version_tag() {
        setup_repo
        git tag list
        git tag foo-v1-rc
        "$SCRIPT"
    }
    It 'ignores tags that are not major versions'
        When call non_version_tag
        The output should equal ''
        The status should be success
    End

    twin_commit_matches() {
        setup_repo
        git tag foo-v1
        commit later
        [ "$("$SCRIPT" | cut -d' ' -f2)" = "$(git rev-parse 'foo-v1^{commit}')" ] && echo same || echo differs
    }
    It 'points the twin at the tagged commit rather than HEAD'
        When call twin_commit_matches
        The output should equal 'same'
    End

    multiple_tags() {
        setup_repo
        git tag foo-v2
        git tag bar-v10
        "$SCRIPT" | cut -d' ' -f1
    }
    It 'prints every missing twin, sorted'
        When call multiple_tags
        The line 1 of output should equal 'bar-v10.0.0'
        The line 2 of output should equal 'foo-v2.0.0'
        The status should be success
    End
End
