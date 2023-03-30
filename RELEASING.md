# Releasing

Each workflow has its own version (i.e. `rust-ci-v1`, `rebuild-all-docker-v2`).
After you merge a PR to main:

- identify workflow files that were modified in your PR
- create a new tag following semver for that file
- move any major or minor version tags forward as appropriate

TODO: build automation that looks at git tags, what files changed, and increments/moves tags for those workflows. Lerna and Pants both have some functionality like this, but most likely something custom to us would be easier for this specific case. Bonus points if the pattern/tool is reusable by others, because this sort of thing is an [open question in the community](https://github.com/orgs/community/discussions/30049) with how new it is.
