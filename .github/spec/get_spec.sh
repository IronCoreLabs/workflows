Describe 'bump-version.get.sh'
    GETSH="$PWD/bump-version.get.sh"

    # Builds a throwaway repo and runs get.sh from inside it, since get.sh discovers version files
    # relative to the working directory.
    setup_repo() {
        REPO=$(mktemp -d)
        mkdir -p "${REPO}/.git"
        ORIGPATH="${PATH}"
    }
    cleanup_repo() {
        rm -rf "${REPO}"
        PATH="${ORIGPATH}"
    }

    # Stands in for the rustup shim, which announces itself on stderr while it installs a pinned
    # toolchain before handing off to the real cargo.
    stub_noisy_cargo() {
        mkdir -p "${REPO}/.stub-bin"
        {
            printf '#!/bin/sh\n'
            printf "echo \"info: syncing channel updates for '1.93.1-x86_64-unknown-linux-gnu'\" 1>&2\n"
            printf 'exec %s "$@"\n' "$(command -v cargo)"
        } > "${REPO}/.stub-bin/cargo"
        chmod +x "${REPO}/.stub-bin/cargo"
        PATH="${REPO}/.stub-bin:${PATH}"
    }

    write_crate() {
        # $1 = dir relative to repo root ("." for the root crate), $2 = crate name, $3 = version
        mkdir -p "${REPO}/$1/src"
        printf 'fn main() {}\n' > "${REPO}/$1/src/main.rs"
        {
            printf '[package]\n'
            printf 'name = "%s"\n' "$2"
            printf 'version = "%s"\n' "$3"
            printf 'edition = "2021"\n'
        } > "${REPO}/$1/Cargo.toml"
    }

    add_workspace_member() {
        printf '\n[workspace]\nmembers = ["%s"]\n' "$1" >> "${REPO}/Cargo.toml"
    }

    run_get() {
        ( cd "${REPO}" && "${GETSH}" )
    }

    BeforeEach 'setup_repo'
    AfterEach 'cleanup_repo'

    It 'reads the version of a single crate'
        write_crate . solo 1.2.3-pre.4
        When call run_get
        The output should equal "1.2.3-pre.4"
        The status should be success
    End

    It 'reads a workspace whose members agree'
        write_crate . zzz-root 5.3.1-pre.2
        write_crate aaa-member aaa-member 5.3.1-pre.2
        add_workspace_member aaa-member
        When call run_get
        The output should equal "5.3.1-pre.2"
        The status should be success
    End

    # Regression: this read every manifest as `cargo metadata ... .packages[0]`, which resolves the
    # whole workspace and orders packages alphabetically. Every file therefore reported the member
    # that sorted first, the mismatch below went unnoticed, and "0.1.0" became the workspace version.
    It 'rejects a workspace whose member disagrees with the root'
        write_crate . zzz-root 5.3.1-pre.2
        write_crate aaa-member aaa-member 0.1.0
        add_workspace_member aaa-member
        When call run_get
        The output should equal ""
        The stderr should not equal ""
        The status should be failure
    End

    It 'ignores a virtual manifest that defines no package'
        printf '[workspace]\nresolver = "2"\nmembers = ["only-member"]\n' > "${REPO}/Cargo.toml"
        write_crate only-member only-member 4.5.6-pre
        When call run_get
        The output should equal "4.5.6-pre"
        The status should be success
    End

    # Regression: cargo's stderr was folded into its stdout with 2>&1, so any chatter ahead of the
    # JSON reached jq and it died with "Invalid numeric literal". Keeping the two apart must not cost
    # us the chatter itself, which is worth having in the log.
    It 'keeps cargo chatter out of the parsed json but still logs it'
        write_crate . solo 9.8.7-pre
        stub_noisy_cargo
        When call run_get
        The output should equal "9.8.7-pre"
        The stderr should include "syncing channel updates"
        The status should be success
    End

    It 'still reports cargo errors that are not a virtual manifest'
        printf 'this is not valid toml\n' > "${REPO}/Cargo.toml"
        When call run_get
        The output should equal ""
        The stderr should not equal ""
        The status should be failure
    End
End
