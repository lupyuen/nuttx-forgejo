#!/usr/bin/env bash
## Sync the Git Commits from NuttX Mirror Repo to NuttX Update Repo
## We use Git Bundles to preserve the Commit Hash. (Git Diff and Git Format Patch won't preserve the Committer Info!)
## Based on https://stackoverflow.com/a/12884254

set -e  ## Exit when any command fails
set -x  ## Echo commands

## Checkout the Upstream and Downstream Repos
tmp_dir=/tmp/sync-mirror-to-update
rm -rf $tmp_dir
mkdir $tmp_dir
cd $tmp_dir
git clone git@nuttx-forge:nuttx/nuttx-mirror upstream
git clone git@nuttx-forge:nuttx/nuttx-update downstream

## Find the First Commit to Sync
set +x ; echo "**** Last Upstream Commit" ; set -x
pushd upstream
upstream_commit=$(git rev-parse HEAD)
git --no-pager log -1
popd
set +x ; echo "**** Last Downstream Commit" ; set -x
pushd downstream
downstream_commit=$(git rev-parse HEAD)
git --no-pager log -1
popd

## If no new Commits to Sync: Quit
if [[ "$downstream_commit" == "$upstream_commit" ]]; then
  set +x ; echo "**** No New Commits to Sync" ; set -x
  exit
fi

## Emit the Commit Bundle for Upstream Repo
pushd upstream
git bundle create \
  $tmp_dir/commit.bundle \
  --branches --tags
popd

## Apply the Commit Bundle to Downstream Repo
pushd downstream
git pull $tmp_dir/commit.bundle master
git status
popd

## Commit the Patched Downstream Repo
pushd downstream
git push -f
popd

## Verify that Upstream and Downstream Commits are identical
set +x ; echo "**** Updated Downstream Commit" ; set -x
pushd downstream
git pull
downstream_commit2=$(git rev-parse HEAD)
git --no-pager log -1
popd

## If Not Identical: We have a problem
if [[ "$downstream_commit2" != "$upstream_commit" ]]; then
  set +x ; echo "**** Sync Failed: Upstream and Downstream Commits don't match!" ; set -x
  exit 1
fi

set +x ; echo "**** Done!" ; set -x
