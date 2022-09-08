![tea.xyz](https://tea.xyz/banner.png)

The infuser manages our docker images for platforms we support.

Obviously this cannot include macOS because *Apple*.

The result is a docker image that contains a c compiler and GNU make, with the
platform’s libc. With this all other tea packages can be built.

Our goal is to provide an image that is just libc and `tea` with a sensible
(stable) kernel choice but currently we are not there.


Getting Started
---------------
    mkdir ~/tea
    cd ~/tea
    git clone https://github.com/teaxyz/cli
    git clone https://github.com/teaxyz/pantry
    git clone https://github.com/teaxyz/infuser

    test -n $GITHUB_TOKEN || echo "GITHUB_TOKEN not set! b0rkage imminent!"

    docker build \
      --tag ghcr.io/teaxyz/infuser:latest \
      --file infuser/Dockerfile \
      --build-arg GITHUB_TOKEN=$GITHUB_TOKEN \
      .

    docker run \
      --env GITHUB_TOKEN \
      --hostname tea \
      --interactive --tty \
      ghcr.io/teaxyz/infuser:latest \
      /bin/bash

The best way to figure out the container name is with the docker
dashboard GUI.

`GITHUB_TOKEN` is required when building tea packages to use the GitHub
GraphQL API for release and tag lookup. You will indeed need to generate a
*personal access token* (PAT) (no additional permissions are required).


Debugging
---------
Debugging is easier if you can hack using your native machine.

    docker run \
      --hostname tea \
      --interactive --tty \
      --volume /opt/tea.xyz/var/www:/opt/tea.xyz/var/www \
      --volume $PWD/pantry:/opt/tea.xyz/var/pantry \
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
echo $GITHUB_TOKEN | docker login ghcr.io -u mxcl --password-stdin

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
  --tag ghcr.io/teaxyz/infuser:$BRANCH \
  --tag ghcr.io/teaxyz/infuser:sha-$SHA7 \
  --platform linux/amd64,linux/arm64 \
  --file infuser/Dockerfile \
  --build-arg GITHUB_TOKEN=$GITHUB_TOKEN \
  .
```

Building the Multi-Arch Image (But Faster)
==========================================

It takes a very long time to build aarch64 on x86-64. So we want to build
natively and then combine them in one step.

> **NOTE** you must use a precise copy of `teaxyz/cli`, `teaxyz/pantry` &
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
  --file infuser/Dockerfile \
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
  --file infuser/Dockerfile \
  --build-arg GITHUB_TOKEN=$GITHUB_TOKEN \
  --cache-from $X86_64_HOSTNAME.local:5000/tea \
  .
```
