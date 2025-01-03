#!/usr/bin/env bash

set +e  ## Ignore errors
set -x  ## Echo commands

for (( ; ; )); do
  $HOME/nuttx-forgejo/sync-mirror-to-update.sh
  date ; sleep 600
done
