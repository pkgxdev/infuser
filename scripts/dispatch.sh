#!/bin/bash

set -euxo pipefail

LOCKFILE=/tmp/dispatch.sh.lock

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
PACKAGE=$(curl -s https://app.tea.xyz/api/builder/nextJob -H "authorization: bearer $TOKEN" | \
 sed -e 's/{"project":"\(.*\)","version":"\(.*\)"}/\1 \2/' -e 's/ \*$//')

if test -z "$PACKAGE"; then
  exit 0
fi

cd /opt/tea.xyz/var/cli
update_from_git
cd ../pantry
update_from_git

set -a
# shellcheck source=/dev/null
. ~/docker.env.tea

# shellcheck disable=SC2086
/opt/tea.xyz/var/infuser/scripts/build-test-bottle-upload.sh $PACKAGE >/opt/tea.xyz/var/log/build-log-aarch64.log 2>&1

docker container prune --force

# shellcheck disable=SC2086
docker run \
  --hostname tea \
  --interactive --tty \
  --volume /opt/tea.xyz/var/pantry:/opt/tea.xyz/var/pantry \
  --volume /opt/tea.xyz/var/cli:/opt/tea.xyz/var/cli \
  --volume /opt/tea.xyz/var/infuser/scripts:/opt/tea.xyz/var/infuser/scripts \
  --workdir /opt/tea.xyz/var/pantry \
  --env-file ~/docker.env.tea \
  ghcr.io/teaxyz/infuser:latest \
  /opt/tea.xyz/var/infuser/scripts/build-test-bottle-upload.sh $PACKAGE \
  >/opt/tea.xyz/var/log/build-log-x86_64.log 2>&1

#TODO: add slack notification