# base
FROM debian:buster-slim

# set the github runner version
ARG RUNNER_VERSION="2.298.2"

# update the base packages and add a non-sudo user
RUN apt-get update -y && apt-get upgrade -y && useradd -m builder

# install python and the packages the your code depends on along with jq so we can parse JSON
# add additional packages as necessary
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    curl build-essential libssl-dev libffi-dev python3 python3-venv python3-dev python3-pip \
    wget awscli strace less vim sudo cron rsyslog

# required for chetan/invalidate-cloudfront-action@v2; must be 1.6 (buster ships 1.5)
RUN curl -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -o /usr/local/bin/jq \
    && chmod a+rx /usr/local/bin/jq
# cd into the user directory, download and unzip the github actions runner
RUN cd /home/builder && mkdir actions-runner && cd actions-runner \
    && ARCH=$(uname -m | sed -e 's/aarch64/arm64/' -e 's/x86_64/x64/') \
    && curl -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz

# Clean the environment
RUN echo ACTIONS_RUNNER_HOOK_JOB_STARTED=/home/builder/pre-run.sh >>/home/builder/actions-runner/.env
COPY pre-run.sh /home/builder/pre-run.sh
RUN chmod +x /home/builder/pre-run.sh

# install some additional dependencies
RUN chown -R builder ~builder /opt && /home/builder/actions-runner/bin/installdependencies.sh

# copy over the start.sh script
COPY start.sh start.sh

# make the script executable
RUN chmod +x start.sh

# copy over the crontab file
COPY crontab crontab

# install the crontab file as root
RUN crontab crontab

# make builder able to run apt-get without a password
RUN usermod -aG sudo builder
RUN echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# since the config and run script for actions are not allowed to be run by root,
# set the user to "builder" so all subsequent commands are run as the builder user
USER builder

# set the entrypoint to the start.sh script
ENTRYPOINT ["./start.sh"]