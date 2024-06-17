ARG JENKINS_INBOUND_AGENT_VERSION=3248.v65ecb_254c298-6

FROM jenkins/inbound-agent:${JENKINS_INBOUND_AGENT_VERSION}-jdk17
USER root
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

## Repeating the ARG from top level to allow them on this scope
# Ref - https://docs.docker.com/engine/reference/builder/#scope
ARG JENKINS_INBOUND_AGENT_VERSION=3248.v65ecb_254c298-6

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
  # Required for installing azure-cli through the debian package
  gpg \
  lsb-release \
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

ARG GH_VERSION=2.51.0
# ARG GH_SHASUM_256="6df9b0214f352fe62b2998c2d1b9828f09c8e133307c855c20c1924134d3da25"
RUN curl --silent --show-error --location --output /tmp/gh.tar.gz \
  "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" \
  # && sha256sum /tmp/gh.tar.gz | grep -q "${GH_SHASUM_256}" \
  && tar xvfz /tmp/gh.tar.gz -C /tmp \
  && mv /tmp/gh_${GH_VERSION}_linux_amd64/bin/gh /usr/local/bin/gh \
  && chmod a+x /usr/local/bin/gh \
  && gh --help

ARG NETLIFY_DEPLOY=0.1.8
RUN mkdir -p /tmp/netlify && \
  curl --silent --show-error --location --output /tmp/netlify.tar.gz \
  "https://github.com/halkeye/netlify-golang-deploy/releases/download/v${NETLIFY_DEPLOY}/netlify-golang-deploy_${NETLIFY_DEPLOY}_Linux_x86_64.tar.gz" \
  && tar xvfz /tmp/netlify.tar.gz -C /tmp/netlify \
  && mv /tmp/netlify/netlify-golang-deploy /usr/local/bin/netlify-deploy \
  && chmod a+x /usr/local/bin/netlify-deploy \
  && rm -rf /tmp/netlify /tmp/netlify.tar.gz \
  && netlify-deploy --help

## Install azcopy
ARG AZCOPY_VERSION=10.25.1-20240612
# Download and install the Microsoft signing key
RUN curl --silent --show-error --location \
  "https://azcopyvnext.azureedge.net/releases/release-${AZCOPY_VERSION}/azcopy_linux_amd64_${AZCOPY_VERSION%-*}.tar.gz" \
  | tar --extract --gzip --strip-components=1 --directory=/usr/local/bin/ --wildcards '*/azcopy' \
  && chmod a+x /usr/local/bin/azcopy \
  && azcopy --version

## Install Azure Cli
ARG AZ_CLI_VERSION=2.61.0
# Download and install the Microsoft signing key
RUN mkdir -p /etc/apt/keyrings \
  && curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/keyrings/microsoft.gpg > /dev/null \
  && chmod go+r /etc/apt/keyrings/microsoft.gpg \
  # Add the Azure CLI software repository
  && AZ_REPO=$(lsb_release -cs) \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | tee /etc/apt/sources.list.d/azure-cli.list \
  # Update repository information and install the azure-cli package
  && apt-get -y update \
  && apt-get -y install --no-install-recommends azure-cli="${AZ_CLI_VERSION}-1~${AZ_REPO}" \
  # Sanity check
  && az version \
  # Cleanup
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG TYPOS_VERSION=1.14.6
# ARG TYPOS_SHASUM_256="27ce43632f09d5dbeb2231fe6bbd7e99eef4ed06a9149cd843d35f70a798058c"
RUN curl --silent --show-error --location --output /tmp/typos.tar.gz \
  "https://github.com/crate-ci/typos/releases/download/v${TYPOS_VERSION}/typos-v${TYPOS_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
  # && sha256sum /tmp/typos.tar.gz | grep -q "${TYPOS_SHASUM_256}" \
  && tar xvfz /tmp/typos.tar.gz -C /usr/local/bin ./typos \
  && chmod a+x /usr/local/bin/typos \
  && typos --help

ARG TYPOS_CHECKSTYLE_VERSION=0.1.1
# ARG TYPOS_CHECKSTYLE_SHASUM_256="547b922873ece451fe45d44e060b571fbbd63ce5b830602fdf847bc6709dc505"
RUN curl --silent --show-error --location --output /tmp/typos-checkstyle \
  "https://github.com/halkeye/typos-json-to-checkstyle/releases/download/v${TYPOS_CHECKSTYLE_VERSION}/typos-checkstyle-v${TYPOS_CHECKSTYLE_VERSION}-x86_64" \
  # && sha256sum /tmp/typos-checkstyle | grep -q "${TYPOS_CHECKSTYLE_SHASUM_256}" \
  && mv /tmp/typos-checkstyle /usr/local/bin/typos-checkstyle \
  && chmod a+x /usr/local/bin/typos-checkstyle \
  && typos-checkstyle --help

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
# NodeJS 18 is needed by the jenkins.io/plugins.jenkins.io websites
# Ruby 3 is needed by some of the jenkins-infra/infra-report and jenkins.io
ARG ASDF_VERSION=0.14.0
RUN bash -c "git clone https://github.com/asdf-vm/asdf.git $HOME/.asdf --branch v${ASDF_VERSION} && \
  echo 'legacy_version_file = yes' > $HOME/.asdfrc && \
  printf 'yarn\njsonlint' > $HOME/.default-npm-packages && \
  . $HOME/.asdf/asdf.sh && \
  asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git && \
  asdf install ruby 3.3.0 && \
  asdf global ruby 3.3.0 && \
  asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git && \
  asdf install nodejs 18.19.0 && \
  asdf global nodejs 18.19.0 && \
  asdf install nodejs 20.11.1"

LABEL io.jenkins-infra.tools="azcopy,azure-cli,git,make,gh,typos,nodejs,npm,jenkins-inbound-agent,netlify-deploy,asdf"
LABEL io.jenkins-infra.tools.gh.version="${GH_VERSION}"
LABEL io.jenkins-infra.tools.jenkins-inbound-agent.version="${JENKINS_INBOUND_AGENT_VERSION}"
LABEL io.jenkins-infra.tools.netlify-deploy.version="${NETLIFY_DEPLOY}"
LABEL io.jenkins-infra.tools.azcopy.version="${AZCOPY_VERSION}"
LABEL io.jenkins-infra.tools.azure-cli.version="${AZ_CLI_VERSION}"
LABEL io.jenkins-infra.tools.asdf.version="${ASDF_VERSION}"
LABEL io.jenkins-infra.tools.typos.version="${TYPOS_VERSION}"
LABEL io.jenkins-infra.tools.typos-checkstyle.version="${TYPOS_CHECKSTYLE_VERSION}"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
