#!/bin/bash

set -euxo pipefail

LOCKFILE=/tmp/dispatch.sh.lock
ENV_FILE=~/docker.env.tea
DOCKER=/Applications/Docker.app/Contents/Resources/bin/docker
TEA_VAR=${TEA_PREFIX:=/opt}/tea.xyz/var


if ! shlock -f "$LOCKFILE" -p $$; then
  exit
fi

trap "rm \\"$LOCKFILE\\"" EXIT

function update_from_git() {
  git reset --hard
  git fetch origin
  git checkout main
  git pull --rebase
}

## BEGIN
set -a
# shellcheck source=/dev/null
. $ENV_FILE

PACKAGE=$(curl -s https://app.tea.xyz/api/builder/nextJob -H "authorization: bearer $TEA_API_TOKEN" | \
 sed -e 's/{"project":"\(.*\)","version":"\(.*\)"}/\1 \2/' -e 's/ \*$//')

if test -z "$PACKAGE"; then
  exit 0
fi

cd $TEA_VAR/cli
update_from_git
cd $TEA_VAR/pantry
update_from_git

# shellcheck disable=SC2086
$TEA_VAR/infuser/scripts/build-test-bottle-upload.sh $PACKAGE >$TEA_VAR/log/build-log-aarch64.log 2>&1

$DOCKER container prune --force

# shellcheck disable=SC2086
$DOCKER run \
  --hostname tea \
  --volume $TEA_VAR/pantry:$TEA_VAR/pantry \
  --volume $TEA_VAR/cli:$TEA_VAR/cli \
  --volume $TEA_VAR/infuser/scripts:$TEA_VAR/infuser/scripts \
  --workdir $TEA_VAR/pantry \
  --env-file ~/docker.env.tea \
  ghcr.io/teaxyz/infuser:latest \
  $TEA_VAR/infuser/scripts/build-test-bottle-upload.sh $PACKAGE \
  >$TEA_VAR/log/build-log-x86_64.log 2>&1

#TODO: add slack notification