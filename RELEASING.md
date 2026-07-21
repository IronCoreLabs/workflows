# Releasing

Each reusable workflow and composite action has a floating major version tag (e.g. `rust-ci-v1`, `docker-v2`). Consuming repos pin to these tags, so moving a tag releases the change to every consumer of that major version.

## Declaring versions

Every reusable workflow declares its current major version in a comment at the top of its yaml file (composite actions declare it in their `action.yaml`):

```yaml
# tag-version: v3
```

## What happens on merge

The `move-tags.yaml` workflow runs on every push to `main` and reconciles tags with content: for each declared version, if the tag `NAME-vN` doesn't exist, or if the workflow's files (its yaml file, its `.github/NAME.*.sh` helper scripts, or the action's directory) differ between the tag and `main`, the tag is created or force-moved to the head of `main`.

- **Non-breaking change:** leave the `tag-version` comment alone. The current tag moves forward when your PR merges.
- **Breaking change:** increment the `tag-version` comment in the same PR. Merging creates the new tag; the old tag stays where it was, and consumers upgrade by editing their workflow references.

On pull requests the same workflow runs in report-only mode: its job summary lists the tags that merging will move, so reviewers can check that a breaking change got a new major version.

Because tags are reconciled against content rather than individual pushes, the automation also catches up on any merges where tags didn't get moved. As a safety guard, it never moves a tag older than the newest one that exists for a workflow, so a stale or accidentally decremented `tag-version` comment can't clobber an old major version.
