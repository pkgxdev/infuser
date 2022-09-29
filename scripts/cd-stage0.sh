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
  git fetch --all
  git reset --hard origin/main
  if test $# -eq 0; then
    git checkout main
    git pull --rebase
  else
    git checkout "$1"
  fi
}

## BEGIN
set -a
# shellcheck source=/dev/null
. $ENV_FILE

R=$(curl -s https://app.tea.xyz/api/builder/nextJob -H "authorization: bearer $TEA_API_TOKEN" | \
 sed -e 's/{"project":"\(.*\)","version":"\(.*\)","sha":"\(.*\)"}/\1 \2 \3/' -e 's/ \*$//')

PACKAGE=$(echo "$R" | cut -d ' ' -f 1-2)
SHA=$(echo "$R" | cut -d ' ' -f 3)

if test -z "$PACKAGE"; then
  exit 0
fi

if test -z "$SHA"; then
  echo "SHA missing"
  exit 1
fi

cd $TEA_VAR/cli
update_from_git
cd $TEA_VAR/pantry
update_from_git "$SHA"

# shellcheck disable=SC2086
$TEA_VAR/infuser/scripts/cd-stage1.sh $PACKAGE >>$TEA_VAR/log/build-log-darwin.log 2>&1

#HACKY: Docker Desktop _really_ wants to use the macOS keychain
HASH=$(echo -n "$GITHUB_USER:$GITHUB_TOKEN" | base64)

echo '{"auths":{"ghcr.io":{"auth":"'"$HASH"'"}}}' >~/.docker/config.json

$DOCKER login ghcr.io
$DOCKER pull ghcr.io/teaxyz/infuser:latest
$DOCKER container prune --force

#FIXME: linux-aarch64 needs OS ca-certificates right now.
#FIXME: linux-aarch64 needs OS shared-mime-info right now.
# shellcheck disable=SC2086
$DOCKER run \
  --hostname tea \
  --volume $TEA_VAR/pantry:$TEA_VAR/pantry \
  --volume $TEA_VAR/cli:$TEA_VAR/cli \
  --volume $TEA_VAR/infuser/scripts:$TEA_VAR/infuser/scripts \
  --workdir $TEA_VAR/pantry \
  --env-file ~/docker.env.tea \
  ghcr.io/teaxyz/infuser:latest \
  bash -c "apt-get install -y shared-mime-info ca-certificates && $TEA_VAR/infuser/scripts/cd-stage1.sh $PACKAGE" \
  >>$TEA_VAR/log/build-log-linux.log 2>&1

#TODO: add slack notification