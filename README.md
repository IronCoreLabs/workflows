# IronCore Labs Workflows

## Bootstrapping

To get workflows set up in a repository, follow these steps. Some of these steps aren't required for these workflows, but they're
collected here to make all our repositories consistent.

1. In the GitHub web UI:
   1. Under `General settings`
      - `Allow auto-merge`: yes
      - `Automatically delete head branches`: yes
   1. Under `Collaborators and teams`
      - `ICL-Engineering`: Admin
      - `Ops`: Admin
      - language-specific group: Admin
      - `leeroy-travis`: Write
   1. Under `Branches`, create a new rule for `main` with these settings
      - `Require a pull request before merging`: yes
        - `Require approvals`: yes
        - `Allow specified actors to bypass required pull requests`: `leeroy-travis`
        - `Do not allow bypassing the above settings`: yes
   1. Under `Code security and analysis`, enable all the things.
1. Review the `.github/CODEOWNERS` file. It's unrelated to the workflows, but now's a good chance to check it.
   - Make sure the any groups appearing in `CODEOWNERS` have been granted at least `Write` access to the repository.
1. Examine existing tags and make sure they're compatible with the new system: It will set tags based on the contents of the
   language-specific version file. If necessary, manually adjust versions so there will be no conflicts.
1. Edit the language-specific version file (`package.json`, `Cargo.toml`, `version.sbt`) and increment to the next pre-release
   version. (E.g., `1.2.3` -> `1.2.4-pre`) Once your PR is merged, `main` should always be a pre-release.
1. Decide which workflows you're going to use. For a service, it'll likely be:
   `bump-version.yaml docker.yaml deploy.yaml` plus a language-specific CI workflow.
1. Commit those changes on a branch. Push, PR, and merge.

## Continuous Deployment

These workflows are modular components of a system to manage "deployments" when a PR is merged to `main`. A "deployment" could mean
updating a deployment in Kubernetes, or it could mean publishing a new release of a public repository.

1. bump-version: Bumps the patch version.
   - Triggered by merge to main.
   - Removes `-pre` or similar from the version, commits and tags, and creates a GitHub prerelease.
   - Bumps the version, adds `-pre`, and commits to main.
2. docker: Builds a docker container.
   - Pushes the container image to a repo.
   - Triggered by a GitHub prerelease, or workflow_dispatch.
   - Mostly idempotent. Can rebuild a docker container from the original tag, but the container may have different OS packages.
   - If triggered by a prerelease, publishes the release. (This triggers the deploy workflow.)
3. deploy: Updates a deployment.
   - Triggered by publishing a release (`prerelease: false`), or workflow_dispatch.
   - Gets the docker tag either from the release name or a workflow_dispatch required parameter.

### Authentication

Several actions require a secret called `WORKFLOW_PAT` to be set to the value
of a personal access token with permissions to operate on various repos. A
personal access token (PAT) has been created for the `leeroy-travis` user in
GitHub, and the value of the token is put into two organization-wide secrets:
the workflow secret WORKFLOW_PAT and also the Dependabot secret WORKFLOW_PAT.

The PAT has been configured with `workflow` and `admin:org.read:org`
permissions.

To rotate the PAT, log in to leeroy-travis, go to Settings ... Developer
settings ... Personal access tokens ... Tokens (classic). Select the
"org WORKFLOW_PAT" token, then "Regenerate token". Set the expiration to
"never" and save, then copy the value of the token. Then log in as an
account that is an admin of the IronCore Labs GitHub organization, go to
IronCore ... Settings ... Secrets and variables ... Actions". Edit the
"WORKFLOW_PAT" secret, click "enter a new value", and paste the PAT value.

Repeat this process for the "Dependabot" secrets, updating "WORKFLOW_PAT".

## Docker Hub

We have a personal access token (PAT) that we use to authenticate to Docker Hub. Its purpose is to bypass rate limits on pulls
from Docker Hub. It shouldn't be necessary on GitHub-owned runners, because they have a special deal with Docker. But on other
runners, especially buildjet, it's important.

The PAT is stored as an organization secret in GitHub, named `DOCKERHUB_TOKEN`. It corresponds to login information kept in
`gdrive/IronCore Engineering/IT_Info/leeroy-travis/docker-hub-info.txt.iron`.

To rotate the token:

1. Log in to Docker Hub.
1. Issue a new PAT. It only needs read access to public repositories.
1. Log in to GitHub.
1. Edit the organization secrets for IronCoreLabs, and replace the value of `DOCKERHUB_TOKEN`.
