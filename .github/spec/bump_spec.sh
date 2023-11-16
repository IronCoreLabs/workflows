Describe 'bump-version.bump.sh'
    testit() {
        GITHUB_OUTPUT=$(mktemp)
        export GITHUB_OUTPUT
        ./bump-version.bump.sh "$1" "$2" "$3"
        local result=$?
        cat "$GITHUB_OUTPUT"
        rm "$GITHUB_OUTPUT"
        return $result
    }

    Describe 'increment version'
        Parameters
            # test name, mode, input version, expected release version, expected development version
            "r#1" release    1.2.3-pre         1.2.3            1.2.4-pre
            "r#2" release    1.2.3-foo         1.2.3            1.2.4-pre
            "r#3" release    1.2.3-pre.4.5.6   1.2.3            1.2.4-pre
            "r#4" release    1.2.3             1.2.3            1.2.4-pre
            "r#5" release    1.2.9-pre         1.2.9            1.2.10-pre
            "r#6" release    1.2.0-pre         1.2.0            1.2.1-pre
            "r#7" release    0.1.119-pre       0.1.119          0.1.120-pre
            "r#8" release    1.2.3-SNAPSHOT    1.2.3            1.2.4-pre
            "p#1" prerelease 1.2.3-pre.4       1.2.3-rc.4       1.2.3-pre.5
            "p#2" prerelease 1.2.3-pre.4.5.6   1.2.3-rc.4.5.6   1.2.3-pre.4.5.7
            "p#3" prerelease 1.2.3-pre         1.2.3-rc.0       1.2.3-pre.1
            "p#4" prerelease 1.2.3             1.2.3-rc.0       1.2.3-pre.1
            "p#5" prerelease 1.2.3_p4-r5-pre.1 1.2.3_p4-r5-rc.1 1.2.3_p4-r5-pre.2
            "p#6" prerelease 1.2.3-SNAPSHOT    1.2.3-rc.0       1.2.3-pre.1
        End
        It "example $1"
            When call testit "$2" "$3"
            The line 1 of output should equal "release=$4"
            The line 2 of output should equal "bumped=$5"
            The status should be success
        End
    End

    It 'allows overriding the release version'
        When call testit release 1.2.3-pre 1.3.0
        The line 1 of output should equal "release=1.3.0"
        The line 2 of output should equal "bumped=1.3.1-pre"
        The status should be success
    End

    Describe 'bad input version'
        Parameters
            # test name, input version, input release version
            "v#1" 1.two.3
            "v#3" 01.2.3
            "v#4" 1.02.3
            "r#1" 1.2.3          1.two.3
        End
        It "rejects bad version $1"
            When call testit release $2 $3
            The output should equal ""
            The stderr should not equal ""
            The status should be failure
        End
    End

    It 'rejects input version 0.0.0'
        When call testit release 0.0.0
        The output should equal ""
        The stderr should not equal ""
        The status should be failure
    End

    It 'rejects release version 0.0.0'
        When call testit release 1.2.3 0.0.0
        The output should equal ""
        The stderr should not equal ""
        The status should be failure
    End

    It 'rejects invalid input mode'
        When call testit rrelease 1.2.3
        The output should equal ""
        The stderr should not equal ""
        The status should be failure
    End
End
