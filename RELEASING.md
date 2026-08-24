# Releasing

Each reusable workflow and composite action has a floating major version tag (e.g. `rust-ci-v1.0.0`, `docker-v2.0.0`). Consuming repos pin to these tags, so moving a tag releases the change to every consumer of that major version.

## Why the tags are dotted

The patch digits are there for Dependabot, which only recognizes a bare `vN` ref when the `v` starts it — `actions/checkout@v7` qualifies, `rust-ci-v1` can't. A consumer pinned to the undotted name never gets an upgrade PR; pinned to `rust-ci-v1.0.0`, it gets one as soon as `rust-ci-v2.0.0` exists.

The tag is not immutable, whatever `1.0.0` suggests. It is force-moved on every content change, and no patch or minor versions are ever cut — the digits satisfy a parser, they don't promise a frozen release.

The undotted tags (`rust-ci-v1`, `docker-v2`, …) are frozen at the last commit before this change and are no longer moved. A repo still pinned to one keeps working, but stops receiving updates.

Superseded majors have dotted twins too — `rust-ci-v2.0.0` mirrors the frozen `rust-ci-v2`. They exist so a consumer that hasn't upgraded yet is still legible to Dependabot, which then offers it the current major. Like the tags they mirror, they never move.

## Declaring versions

Every reusable workflow declares its current major version in a comment at the top of its yaml file (composite actions declare it in their `action.yaml`):

```yaml
# tag-version: v3
```

## What happens on merge

The `move-tags.yaml` workflow runs on every push to `main` and reconciles tags with content: for each declared version, if the tag `NAME-vN.0.0` doesn't exist, or if the workflow's files (its yaml file, its `.github/NAME.*.sh` helper scripts, or the action's directory) differ between the tag and `main`, the tag is created or force-moved to the head of `main`.

- **Non-breaking change:** leave the `tag-version` comment alone. The current tag moves forward when your PR merges.
- **Breaking change:** increment the `tag-version` comment in the same PR. Merging creates the new tag; the old tag stays where it was, and consumers upgrade by merging the Dependabot PR it produces.

On pull requests the same workflow runs in report-only mode: its job summary lists the tags that merging will move, so reviewers can check that a breaking change got a new major version.

Because tags are reconciled against content rather than individual pushes, the automation also catches up on any merges where tags didn't get moved. Misconfigurations fail the check: a reusable workflow or action with no parseable `tag-version` comment (it would never be released), or a declared version older than the newest existing tag (moving the old tag would break its consumers). Problems are reported in the PR comment, and no tags are moved on `main` until they're fixed.
