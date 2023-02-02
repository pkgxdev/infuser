![tea.xyz](https://tea.xyz/banner.png)

A container with `tea` and its magic installed and functional.

```sh
docker run --rm -it ghcr.io/teaxyz/infuser
```

# Host Your Own GitHub Actions Runner

Until Github Actions supports aarch64 runners, we need to self host them.
Darwin is pretty easy, but Linux might be even easier. Checkout out
`gha-runner/Dockerfile`. It should be as simple as:

```sh
docker build --tag runner-image gha-runner

docker run \
  --detach \
  --restart=unless-stopped \
  --env ORGANIZATION=$UR_GITHUB_ORG \
  --env ACCESS_TOKEN=$(gh auth token) \
  runner-image
```

Token requires the `repo`, `workflow`, and `admin:org` scopes.


# Bootstrapping a tea Pantry

`Dockerfile.bootstrap` can create an image ready to bootstrap packages for a
platform tea doesn’t yet support.

The result is a docker image that contains a c compiler and GNU make, with the
platform’s libc. With this all other tea packages can be built.

```sh
mkdir ~/tea
cd ~/tea
git clone https://github.com/teaxyz/cli
git clone https://github.com/teaxyz/pantry.core
git clone https://github.com/teaxyz/pantry.extra
git clone https://github.com/teaxyz/infuser

docker build \
  --tag ghcr.io/teaxyz/infuser:latest \
  --file infuser/Dockerfile.bootstrap \
  --build-arg GITHUB_TOKEN=$(gh auth token) \
  .

docker run \
  --env GITHUB_TOKEN=$(gh auth token) \
  --hostname tea \
  --interactive --tty \
  ghcr.io/teaxyz/infuser:latest \
  /bin/bash
```

A `GITHUB_TOKEN` is required when building tea packages to use the GitHub
GraphQL API for release and tag lookup. A PAT with no other permissions is
acceptable though it is easiest to use `gh` as above.


Debugging
---------
Debugging is easier if you can hack using your native machine.

    docker run \
      --hostname tea \
      --interactive --tty \
      --volume /opt/tea.xyz/var/www:/opt/tea.xyz/var/www \
      --volume $PWD/pantry.core:/opt/tea.xyz/var/pantry \
      --volume $PWD/cli:/opt/tea.xyz/var/cli \
      --workdir /opt/tea.xyz/var/pantry \
      --env GITHUB_TOKEN \
      ghcr.io/teaxyz/infuser:latest \
      /bin/bash

Since nobody understands docker I am documenting here that you can
“resume” your shell session in the above container created by `docker run`:

    docker start $container
    docker attach $container


Troubleshooting
---------------
Use `--progress=plain` in the `docker build` instantiation to get logs


Publishing Local Images
-----------------------
At this early stage we are building certain images locally and pushing to
the GitHub package registry. This is not as secure as we’d like so we will be
changing it.

```sh
HOST=ghcr.io/teaxyz/infuser
docker tag $HOST:latest $HOST:sha-$SHA
docker tag $HOST:latest $HOST:$BRANCH

# https://github.com/settings/tokens/new
#  => write:packages read:packages
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USER --password-stdin

docker push $HOST:latest
docker push $HOST:$BRANCH
docker push $HOST:sha-$SHA
```

Building a Multi-arch Image
---------------------------

```sh
# first time only
docker buildx create --name mybuilder --use
```

```sh
cd ~/tea
docker buildx build \
  --pull --push \
  --tag ghcr.io/teaxyz/infuser:latest \
  --tag ghcr.io/teaxyz/infuser:$(git -C infuser branch --show-current) \
  --tag ghcr.io/teaxyz/infuser:sha-$(git -C infuser rev-parse --short HEAD) \
  --platform linux/amd64,linux/arm64 \
  --file infuser/Dockerfile.bootstrap \
  --build-arg GITHUB_TOKEN=$GITHUB_TOKEN \
  .
```

Building the Multi-Arch Image (But Faster)
==========================================

It takes a very long time to build aarch64 on x86-64. So we want to build
natively and then combine them in one step.

> **NOTE** you must use a precise copy of `teaxyz/cli`, `teaxyz/pantry.core` &
> `teaxyz/infuser` on both machines.
> Use `rsync -Rav ~/tea $X86_64_HOSTNAME.local:tea`.
> You may need to add `.git` to `~/tea/.dockerignore`.

```sh
# first time only on both machines
<<-EOS >./buildx.cnf.toml
[registry."$X86_64_HOSTNAME.local:5000"]
  http = true
  insecure = true
EOS
docker buildx create --name tea.builder --use --config ./buildx.cnf.toml

# the config means we can run our own registry (for caching the aarch64
# layers) without having to mess around for `https`.
```

```sh
# run a registry on $X86_64_HOSTNAME
docker run -d -p 5000:5000 --name registry --restart=always registry:latest

# note you will need to set up your docker daemons to use insecure registries
# see: https://www.allisonthackston.com/articles/local-docker-registry.html
```

```sh
# on the aarch64 machine
docker buildx build \
  --platform linux/arm64 \
  --tag ghcr.io/teaxyz/infuser:latest \
  --file infuser/Dockerfile.bootstrap \
  --load \
  --build-arg GITHUB_TOKEN=$GITHUB_TOKEN \
  --cache-to type=registry,ref=$X86_64_HOSTNAME.local:5000/tea,mode=max \
  .
```

```sh
# on the x86-64 machine
docker buildx build \
  --push --pull \
  --tag ghcr.io/teaxyz/infuser:latest \
  --tag ghcr.io/teaxyz/infuser:$(git -C infuser branch --show-current) \
  --tag ghcr.io/teaxyz/infuser:sha-$(git -C infuser rev-parse --short HEAD) \
  --platform linux/amd64,linux/arm64 \
  --file infuser/Dockerfile.bootstrap \
  --build-arg GITHUB_TOKEN=$GITHUB_TOKEN \
  --cache-from $X86_64_HOSTNAME.local:5000/tea \
  .
```

Note that the image will be on GitHub but *not* your local docker. lol.
Docker is a mess. Supposedly replacing ``-push` with `--output=docker` would
fix this but for me: it did nothing.

Cross-running multi-arch images
===============================

If you're even crazier, you can run the alternate architectures using docker's QEMU emulation:

(N.B. This will be slow.)

```sh
docker run \
  --hostname tea \
  --interactive --tty \
  --volume /opt/tea.xyz/var/www:/opt/tea.xyz/var/www \
  --volume $PWD/pantry.core:/opt/tea.xyz/var/pantry \
  --volume $PWD/cli:/opt/tea.xyz/var/cli \
  --workdir /opt/tea.xyz/var/pantry \
  --platform linux/amd64 \
  --env GITHUB_TOKEN \
  ghcr.io/teaxyz/infuser:latest \
  /bin/bash
```
