Describe 'move-tags.list.sh'
    SCRIPT="$PWD/move-tags.list.sh"

    cleanup() {
        if [ -n "${SANDBOX:-}" ] ; then
            cd /
            rm -rf "$SANDBOX"
        fi
    }
    After 'cleanup'

    # Create a sandbox git repo to run the script in.
    setup_repo() {
        SANDBOX=$(mktemp -d)
        cd "$SANDBOX" || return 1
        export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
            GIT_AUTHOR_NAME=spec GIT_AUTHOR_EMAIL=spec@example.com \
            GIT_COMMITTER_NAME=spec GIT_COMMITTER_EMAIL=spec@example.com
        git init -q -b main .
        mkdir -p .github/workflows
    }

    commit_all() {
        git add -A .
        git commit -q -m 'commit'
    }

    # A minimal reusable workflow declaring the given tag-version.
    reusable_workflow() {
        printf '# tag-version: %s\non:\n  workflow_call:\n' "$1"
    }

    new_workflow() {
        setup_repo
        reusable_workflow v1 > .github/workflows/foo.yaml
        commit_all
        "$SCRIPT"
    }
    It 'creates the tag for a new workflow'
        When call new_workflow
        The output should equal 'foo-v1'
        The status should be success
    End

    up_to_date_workflow() {
        setup_repo
        reusable_workflow v1 > .github/workflows/foo.yaml
        commit_all
        git tag foo-v1
        "$SCRIPT"
    }
    It 'is quiet when the tag matches the content'
        When call up_to_date_workflow
        The output should equal ''
        The status should be success
    End

    changed_workflow() {
        setup_repo
        reusable_workflow v1 > .github/workflows/foo.yaml
        commit_all
        git tag foo-v1
        printf '# a change\n' >> .github/workflows/foo.yaml
        commit_all
        "$SCRIPT"
    }
    It 'moves the tag when the workflow file changed'
        When call changed_workflow
        The output should equal 'foo-v1'
        The status should be success
    End

    unrelated_change() {
        setup_repo
        reusable_workflow v1 > .github/workflows/foo.yaml
        commit_all
        git tag foo-v1
        printf 'docs\n' > README.md
        commit_all
        "$SCRIPT"
    }
    It 'ignores changes outside the workflow files'
        When call unrelated_change
        The output should equal ''
        The status should be success
    End

    changed_helper_script() {
        setup_repo
        reusable_workflow v1 > .github/workflows/foo.yaml
        commit_all
        git tag foo-v1
        printf 'echo hi\n' > .github/foo.build.sh
        commit_all
        "$SCRIPT"
    }
    It 'moves the tag when a helper script changed'
        When call changed_helper_script
        The output should equal 'foo-v1'
        The status should be success
    End

    major_bump() {
        setup_repo
        reusable_workflow v1 > .github/workflows/foo.yaml
        commit_all
        git tag foo-v1
        reusable_workflow v2 > .github/workflows/foo.yaml
        commit_all
        "$SCRIPT"
    }
    It 'creates the new tag on a major bump, leaving the old one alone'
        When call major_bump
        The output should equal 'foo-v2'
        The status should be success
    End

    decremented_version() {
        setup_repo
        reusable_workflow v2 > .github/workflows/foo.yaml
        commit_all
        git tag foo-v2
        reusable_workflow v1 > .github/workflows/foo.yaml
        commit_all
        "$SCRIPT"
    }
    It 'refuses to move a tag older than the newest existing one'
        When call decremented_version
        The output should equal ''
        The stderr should not equal ''
        The status should be success
    End

    reusable_without_version() {
        setup_repo
        printf 'on:\n  workflow_call:\n' > .github/workflows/foo.yaml
        commit_all
        "$SCRIPT"
    }
    It 'warns about a reusable workflow with no tag-version comment'
        When call reusable_without_version
        The output should equal ''
        The stderr should not equal ''
        The status should be success
    End

    repo_ci_without_version() {
        setup_repo
        printf 'on:\n  push:\n' > .github/workflows/repo-ci.yaml
        commit_all
        "$SCRIPT"
    }
    It 'silently skips non-reusable workflows with no tag-version comment'
        When call repo_ci_without_version
        The output should equal ''
        The stderr should equal ''
        The status should be success
    End

    changed_action() {
        setup_repo
        mkdir -p .github/actions/tsp
        printf '# tag-version: v1\nname: tsp\n' > .github/actions/tsp/action.yaml
        commit_all
        git tag tsp-v1
        printf 'echo hi\n' > .github/actions/tsp/helper.sh
        commit_all
        "$SCRIPT"
    }
    It 'moves the tag when any file in a composite action changed'
        When call changed_action
        The output should equal 'tsp-v1'
        The status should be success
    End

    multiple_workflows() {
        setup_repo
        reusable_workflow v1 > .github/workflows/foo.yaml
        reusable_workflow v2 > .github/workflows/bar.yaml
        commit_all
        "$SCRIPT"
    }
    It 'prints multiple tags sorted'
        When call multiple_workflows
        The line 1 of output should equal 'bar-v2'
        The line 2 of output should equal 'foo-v1'
        The status should be success
    End
End
