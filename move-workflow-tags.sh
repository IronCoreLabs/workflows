#!/usr/bin/env bash
set -euo pipefail

die() { echo "❌ $*" >&2; exit 1; }

# Make sure we’re where we expect
repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "Not inside a git repo"
cd "$repo_root"

# Accept a commit or range argument (default HEAD). If it's a commit,
# create a range like COMMIT~1..COMMIT.
COMMIT_ARG="${1:-HEAD}"
if [[ "$COMMIT_ARG" == *..* ]]; then
  DIFF_RANGE="$COMMIT_ARG"
else
  DIFF_RANGE="${COMMIT_ARG}~1..${COMMIT_ARG}"
fi

# Find all workflow files under .github/workflows
mapfile -t workflow_files < <(find .github/workflows -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print 2>/dev/null || true)
(( ${#workflow_files[@]} )) || die "No workflow files found in .github/workflows (*.yml|*.yaml)"

# Derive workflow names from filenames (e.g. `bump-version.yaml` -> `bump-version`)
workflows=()
for f in "${workflow_files[@]}"; do
  base=$(basename "$f")
  name="${base%.*}"
  workflows+=("$name")
done

# Get all the tags from the repo
mapfile -t all_tags < <(git tag --list)

# For each workflow, determine the latest version tag (e.g. select `rust-ci-v1` over `rust-ci-v0`)
declare -A latest_tag
for wf in "${workflows[@]}"; do
  best=""
  bestn=-1
  for t in "${all_tags[@]}"; do
    if [[ "$t" =~ ^${wf}-v([0-9]+)$ ]]; then
      n="${BASH_REMATCH[1]}"
      if (( n > bestn )); then
        bestn="$n"
        best="$t"
      fi
    fi
  done
  latest_tag["$wf"]="$best"
done

# Detect changed workflows in the commit range
declare -A changed_map=()
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  base=$(basename "$path")
  name="${base%.*}"
  changed_map["$name"]=1
done < <(git diff --name-only "$DIFF_RANGE" -- .github/workflows/ 2>/dev/null || true)

# Detect changes in related helper scripts under .github/
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  base=$(basename "$path")
  prefix="${base%%.*}"   # e.g. bump-version.bump.sh → bump-version
  if [[ " ${workflows[*]} " == *" $prefix "* ]]; then
    changed_map["$prefix"]=1
  fi
done < <(git diff --name-only "$DIFF_RANGE" -- .github/ 2>/dev/null || true)

# Prompt to select which tags to move
echo "Select workflows to move tags for (space-separated indices, or * for all changed) [commit: $COMMIT_ARG]:"
i=1
for wf in "${workflows[@]}"; do
  mark=""
  [[ -n "${changed_map[$wf]:-}" ]] && mark="*"
  lt="${latest_tag[$wf]}"
  [[ -z "$lt" ]] && lt="none"
  printf "%2d) %-24s %1s (latest: %s)\n" "$i" "$wf" "$mark" "$lt"
  ((i++))
done
echo "(* = changed in $DIFF_RANGE)"
printf "#? "
read -r indices

selected=()
# If * is given, include all workflows marked as changed
if [[ "$indices" == "*" ]]; then
  for wf in "${workflows[@]}"; do
    if [[ -n "${changed_map[$wf]:-}" ]]; then
      selected+=("$wf")
    fi
  done
  echo "Selected all changed workflows: ${selected[*]}"
# Otherwise, parse indices and map them to workflows
else
  for idx in $indices; do
    if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= ${#workflows[@]} )); then
      selected+=("${workflows[$((idx-1))]}")
    else
      echo "Skipping invalid index: $idx" >&2
    fi
  done
fi

(( ${#selected[@]} )) || die "No workflows selected"

# Resolve the commit SHA of the target commit
target_sha=$(git rev-parse --verify "$COMMIT_ARG") || die "Invalid commit-ish: $COMMIT_ARG"

# Output which tags should move and to which SHA
echo
commands=()
for wf in "${selected[@]}"; do
  tag="${latest_tag[$wf]}"
  if [[ -z "$tag" ]]; then
    echo "⚠️  No existing tag for $wf (skipping)"
    continue
  fi
  commands+=("git tag -f $tag $target_sha")
  commands+=("git push -f origin $tag")
done

echo -e "\nProposed tag updates:\n"

# Print out tag update commands
for cmd in "${commands[@]}"; do
  echo "$cmd"
done

echo -e "\nReminder: this is a helper script that could contain mistakes. Always verify the commands manually for accuracy."
echo "If something goes wrong, you can look at the output from the \`git tag\` commands to see what hash the tag used to point to."
