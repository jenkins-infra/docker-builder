ARG JENKINS_INBOUND_AGENT_VERSION=3107.v665000b_51092-4

FROM jenkins/inbound-agent:${JENKINS_INBOUND_AGENT_VERSION}-jdk11
USER root
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

## Repeating the ARG from top level to allow them on this scope
# Ref - https://docs.docker.com/engine/reference/builder/#scope
ARG JENKINS_INBOUND_AGENT_VERSION=3107.v665000b_51092-4

## The packages installed below should always be in their "latest" available version (otherwise needs a separated block), hence disabling the lint rule DL3008
# hadolint ignore=DL3008
RUN \
  apt-get -y update && \
  LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  # Used to download binaries (implies the package "ca-certificates" as a dependency)
  curl \
  # Dev. Tooling packages (e.g. tools provided by this image installable through Alpine Linux Packages)
  git \
  make \
  build-essential \
  jq \
  # jenkins.io archives stuff
  zip \
  # python
  python3 \
  python3-pip \
  # Required for installing azure-cli through pip (the debian package is not multi-arch)
  python3-dev \
  # Required for building Ruby
  libssl-dev libreadline-dev zlib1g-dev \
  # Required for some of the ruby gems that will be installed
  libyaml-dev libncurses5-dev libffi-dev libgdbm-dev \
  # UI libraries so playwright UI tests can be run
  libglib2.0-0 libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libdbus-1-3 libxcb1 libxkbcommon0 libx11-6 libxcomposite1 libxdamage1 \
    libxext6 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libasound2 libatspi2.0-0 libwayland-client0 \
  && \
  apt-get clean &&\
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# plugin site
ARG BLOBXFER_VERSION=1.11.0
# hadolint ignore=DL3018
RUN pip3 install --no-cache-dir blobxfer=="${BLOBXFER_VERSION}" && blobxfer --version

ARG GH_VERSION=2.23.0
# ARG GH_SHASUM_256="6df9b0214f352fe62b2998c2d1b9828f09c8e133307c855c20c1924134d3da25"
RUN curl --silent --show-error --location --output /tmp/gh.tar.gz \
  "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" \
  # && sha256sum /tmp/gh.tar.gz | grep -q "${GH_SHASUM_256}" \
  && tar xvfz /tmp/gh.tar.gz -C /tmp \
  && mv /tmp/gh_${GH_VERSION}_linux_amd64/bin/gh /usr/local/bin/gh \
  && chmod a+x /usr/local/bin/gh \
  && gh --help

ARG NETLIFY_DEPLOY=0.1.5
RUN mkdir -p /tmp/netlify && \
  curl --silent --show-error --location --output /tmp/netlify.tar.gz \
  "https://github.com/halkeye/netlify-golang-deploy/releases/download/v${NETLIFY_DEPLOY}/netlify-golang-deploy_${NETLIFY_DEPLOY}_Linux_x86_64.tar.gz" \
  && tar xvfz /tmp/netlify.tar.gz -C /tmp/netlify \
  && mv /tmp/netlify/netlify-golang-deploy /usr/local/bin/netlify-deploy \
  && chmod a+x /usr/local/bin/netlify-deploy \
  && rm -rf /tmp/netlify /tmp/netlify.tar.gz \
  && netlify-deploy --help

## Install Azure Cli
ARG AZ_CLI_VERSION=2.45.0
# hadolint ignore=DL3013,DL3018
RUN pip3 install --no-cache-dir azure-cli=="${AZ_CLI_VERSION}" && az --version

ARG USER=jenkins
ENV XDG_RUNTIME_DIR=/run/${USER}/1000

RUN mkdir -p "${XDG_RUNTIME_DIR}" \
  && chown -R "${USER}" "${XDG_RUNTIME_DIR}" \
  && echo "${USER}":100000:65536 | tee /etc/subuid | tee /etc/subgid

COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod a+x /usr/local/bin/entrypoint.sh

USER "${USER}"
ENV USER=${USER}
ENV HOME=/home/"${USER}"

# Install ASDF to install custom tools
# Ruby 2 and NodeJS 18 is needed by the jenkins.io/plugins.jenkins.io websites
# Ruby 3 is needed by some of the jenkins-infra/infra-report
ARG ASDF_VERSION=0.11.1
RUN bash -c "git clone https://github.com/asdf-vm/asdf.git $HOME/.asdf --branch v${ASDF_VERSION} && \
  echo 'legacy_version_file = yes' > $HOME/.asdfrc && \
  printf 'yarn\njsonlint' > $HOME/.default-npm-packages && \
  . $HOME/.asdf/asdf.sh && \
  asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git && \
  asdf install ruby 2.7.7 && \
  asdf install ruby 3.2.1 && \
  asdf global ruby 2.7.7 && \
  asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git && \
  asdf install nodejs 18.14.0 && \
  asdf global nodejs 18.14.0"

LABEL io.jenkins-infra.tools="azure-cli,git,make,gh,nodejs,npm,blobxfer,jenkins-inbound-agent,netlify-deploy,asdf"
LABEL io.jenkins-infra.tools.blobxfer.version="${BLOBXFER_VERSION}"
LABEL io.jenkins-infra.tools.gh.version="${GH_VERSION}"
LABEL io.jenkins-infra.tools.jenkins-inbound-agent.version="${JENKINS_INBOUND_AGENT_VERSION}"
LABEL io.jenkins-infra.tools.netlify-deploy.version="${NETLIFY_DEPLOY}"
LABEL io.jenkins-infra.tools.azure-cli.version="${AZ_CLI_VERSION}"
LABEL io.jenkins-infra.tools.asdf.version="${ASDF_VERSION}"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
