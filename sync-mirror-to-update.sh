#!/usr/bin/env bash
## Sync the Git Commits from NuttX Mirror Repo to NuttX Update Repo

set -e  ## Exit when any command fails
set -x  ## Echo commands

## Get the Script Directory
script_path="${BASH_SOURCE}"
script_dir="$(cd -P "$(dirname -- "${script_path}")" >/dev/null 2>&1 && pwd)"

## Checkout the Upstream and Downstream Repos
tmp_dir=/tmp/sync-mirror-to-update
rm -rf $tmp_dir
mkdir $tmp_dir
cd $tmp_dir
git clone https://nuttx-forge.org/nuttx/nuttx-mirror upstream
git clone git@nuttx-forge:nuttx/nuttx-update downstream

## Find out which Commit to begin
pushd downstream
commit=$(git rev-parse HEAD)
popd

## Emit the Commit Patches for Upstream Repo
pushd upstream
git format-patch \
  $commit..HEAD \
  --stdout \
  >$tmp_dir/commit.patch
cat $tmp_dir/commit.patch
popd

## Apply the Commit Patches to Downstream Repo
pushd downstream
## git am \
##   $tmp_dir/commit.patch
git status
popd

## Commit the Patched Downstream Repo
pushd downstream
## git push -f
popd

exit


set +x ; echo "**** Waiting for Build to Complete then Ingest GitHub Actions Logs..." ; set -x
pushd $script_dir/../ingest-nuttx-builds
./github.sh  ## https://github.com/lupyuen/ingest-nuttx-builds/blob/main/github.sh
popd

## Repeat forever
for (( ; ; )); do

  set +x ; echo "**** Checking Downstream Commit: Enable macOS Builds..." ; set -x
  pushd downstream
  git pull
  downstream_msg=$(git log -1 --format="%s")
  if [[ "$downstream_msg" != "Enable macOS Builds"* ]]; then
    set +x ; echo "**** ERROR: Expected Downstream Commit to be 'Enable macOS Builds' but found: $downstream_msg" ; set -x
    exit 1
  fi
  popd

  set +x ; echo "**** Watching for Updates to NuttX Repo..." ; set -x
  ## Get the Latest Upstream Commit.
  pushd upstream
  git pull
  upstream_date=$(git log -1 --format="%cI")
  git --no-pager log -1
  popd

  ## Get the Latest Downstream Commit (skip the "Enable macOS Builds")
  pushd downstream
  downstream_date=$(git log -1 --format="%cI" HEAD~1)
  git --no-pager log -1 HEAD~1
  popd

  ## If No Updates: Try again
  if [[ "$upstream_date" == "$downstream_date" ]]; then
    set +x ; echo "**** Waiting for upstream updates..." ; set -x
    date ; sleep 900
    continue
  fi

  set +x ; echo "**** Discarding 'Enable macOS' commit from NuttX Mirror..." ; set -x
  pushd downstream
  git --no-pager log -1
  git reset --hard HEAD~1
  git status
  git push -f
  popd
  sleep 10

  set +x ; echo "**** Syncing NuttX Mirror with NuttX Repo..." ; set -x
  gh repo sync NuttX/nuttx --force
  pushd downstream
  git pull
  git status
  git --no-pager log -1
  popd
  sleep 10

  set +x ; echo "**** Building NuttX Mirror..." ; set -x
  $script_dir/enable-macos-windows.sh  ## https://github.com/lupyuen/nuttx-release/blob/main/enable-macos-windows.sh

  set +x ; echo "**** Waiting for Build to start..." ; set -x
  date ; sleep 900

  set +x ; echo "**** Waiting for Build to Complete then Ingest GitHub Actions Logs..." ; set -x
  pushd $script_dir/../ingest-nuttx-builds
  ./github.sh  ## https://github.com/lupyuen/ingest-nuttx-builds/blob/main/github.sh
  popd

  set +x ; echo "**** Done!" ; set -x
  date ; sleep 900
done
