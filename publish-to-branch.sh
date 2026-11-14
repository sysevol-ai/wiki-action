#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 CodeNib Contributors
#
# SPDX-License-Identifier: Apache-2.0

# Writes the built Wiki into one folder of the branch that GitHub Pages serves
# and pushes it, leaving the rest of that branch alone.
#
# Inputs (environment): INPUT_REPOSITORY_PATH, BRANCH, WIKI_PATH, SITE_PATH,
# RUNNER_TEMP. The checkout's credentials push the commit, so the workflow
# needs `contents: write`.
set -euo pipefail

fail() {
  echo "::error title=CodeNib Wiki::$1"
  exit 1
}

repo="$(cd "$INPUT_REPOSITORY_PATH" && pwd)"
site="$(cd "$SITE_PATH" && pwd)"
work="${RUNNER_TEMP:?}/codenib-pages-branch"
remote_ref="refs/remotes/origin/$BRANCH"

[[ -f "$site/codenib-static.json" ]] || fail "The built Wiki at $site has no codenib-static.json."

# shellcheck disable=SC2329 # run by the EXIT trap
cleanup() {
  git -C "$repo" worktree remove --force "$work" >/dev/null 2>&1 || rm -rf "$work"
}
trap cleanup EXIT
rm -rf "$work"
git -C "$repo" worktree prune

created=false
if git -C "$repo" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  git -C "$repo" fetch --no-tags --depth=1 origin "+refs/heads/$BRANCH:$remote_ref"
  git -C "$repo" worktree add --quiet --detach "$work" "$remote_ref"
else
  created=true
  git -C "$repo" worktree add --quiet --detach "$work"
  git -C "$work" checkout --quiet --orphan "codenib-wiki-$BRANCH"
  git -C "$work" rm -rfq --ignore-unmatch .
  git -C "$work" clean -fdxq
  echo "::notice title=CodeNib Wiki::Created branch $BRANCH. Serve it under Settings > Pages > Deploy from a branch."
fi

target="$work/$WIKI_PATH"

# Never replace a folder that the last run did not write.
if [[ -e "$target" && ! -f "$target/codenib-static.json" ]]; then
  fail "$BRANCH already has $WIKI_PATH/ and it is not a CodeNib Wiki. Choose another path."
fi

# A branch built by Jekyll drops files whose names start with an underscore.
if [[ "$created" == true ]]; then
  touch "$work/.nojekyll"
elif [[ ! -e "$work/.nojekyll" ]]; then
  hidden="$(cd "$site" && find . -name '_*' -print -quit)"
  if [[ -n "$hidden" ]]; then
    fail "GitHub Pages builds $BRANCH with Jekyll, which leaves out files such as ${hidden#./}. Add an empty .nojekyll file to the root of $BRANCH if the site does not need Jekyll, or use deploy: none."
  fi
fi

rm -rf "$target"
mkdir -p "$target"
cp -R "$site/." "$target/"

git -C "$work" add -A -- "$WIKI_PATH"
[[ "$created" == true ]] && git -C "$work" add -- .nojekyll
if git -C "$work" diff --cached --quiet; then
  echo "The Wiki in $BRANCH:$WIKI_PATH is already up to date."
  exit 0
fi

source_commit="$(git -C "$repo" rev-parse HEAD)"
git -C "$work" \
  -c user.name="github-actions[bot]" \
  -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit --quiet -m "Update the CodeNib Wiki in $WIKI_PATH for ${source_commit:0:12}"

# Another workflow may push to the same branch; replay this commit on top.
for attempt in 1 2 3; do
  if git -C "$work" push --quiet origin "HEAD:refs/heads/$BRANCH"; then
    echo "Wrote the Wiki to $BRANCH:$WIKI_PATH/."
    exit 0
  fi
  [[ "$attempt" == 3 ]] && break
  sleep $((attempt * 5))
  git -C "$repo" fetch --no-tags origin "+refs/heads/$BRANCH:$remote_ref"
  if ! git -C "$work" \
    -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    rebase --quiet "$remote_ref"; then
    git -C "$work" rebase --abort || true
    fail "Another push changed $WIKI_PATH/ on $BRANCH at the same time. Run the workflow again."
  fi
done
fail "Could not push to $BRANCH. Check that the workflow grants contents: write."
