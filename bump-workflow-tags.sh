#!/usr/bin/env bash
set -euo pipefail

die() { echo "❌ $*" >&2; exit 1; }

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "Not inside a git repo"
cd "$repo_root"

COMMIT_ARG="${1:-HEAD}"
if [[ "$COMMIT_ARG" == *..* ]]; then
  DIFF_RANGE="$COMMIT_ARG"
else
  DIFF_RANGE="${COMMIT_ARG}~1..${COMMIT_ARG}"
fi

mapfile -t workflow_files < <(find .github/workflows -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print 2>/dev/null || true)
(( ${#workflow_files[@]} )) || die "No workflow files found in .github/workflows (*.yml|*.yaml)"

workflows=()
for f in "${workflow_files[@]}"; do
  base=$(basename "$f")
  name="${base%.*}"
  workflows+=("$name")
done

mapfile -t all_tags < <(git tag --list)

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

declare -A changed_map=()
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  base=$(basename "$path")
  name="${base%.*}"
  changed_map["$name"]=1
done < <(git diff --name-only "$DIFF_RANGE" -- .github/workflows/ 2>/dev/null || true)

echo "Select workflows to bump (space-separated indices, or * for all changed) [commit: $COMMIT_ARG]:"
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

if [[ "$indices" == "*" ]]; then
  for wf in "${workflows[@]}"; do
    if [[ -n "${changed_map[$wf]:-}" ]]; then
      selected+=("$wf")
    fi
  done
  echo "Selected all changed workflows: ${selected[*]}"
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

target_sha=$(git rev-parse --verify "$COMMIT_ARG") || die "Invalid commit-ish: $COMMIT_ARG"

echo
echo "Planned tag updates (moving tags to $target_sha):"
commands=()
for wf in "${selected[@]}"; do
  tag="${latest_tag[$wf]}"
  if [[ -z "$tag" ]]; then
    echo " ⚠️  No existing tag for $wf (skipping)"
    continue
  fi
  echo " git tag -f $tag $target_sha"
  echo " git push -f origin $tag"
  commands+=("git tag -f $tag $target_sha")
  commands+=("git push -f origin $tag")
done

echo
read -rp "Proceed? [y/N] " yn
if [[ ! "$yn" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

for cmd in "${commands[@]}"; do
  echo "+ $cmd"
  eval "$cmd"
done

echo "✅ Done."
