# The official img's image is required to retrieve the img and new*idmap binaries
ARG IMG_VERSION=0.5.11
ARG JX_RELEASE_VERSION=2.5.2
ARG JENKINS_AGENT_VERSION=4.13-2
ARG ASDF_VERSION=0.8.1

FROM ghcr.io/jenkins-x/jx-release-version:${JX_RELEASE_VERSION} AS jx-release-version
FROM r.j3ss.co/img:v${IMG_VERSION} AS img

# Alpine is used by default for fast and ligthweight customization with a fixed minor to benefit of the latest patches
FROM jenkins/inbound-agent:${JENKINS_AGENT_VERSION}-jdk11
USER root
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

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
  # Required for img's builds
  pigz \
  jq \
  # jenkins.io archives stuff
  zip \
  # python
  python3 \
  python3-pip \
  # Required for building Ruby
  libssl-dev libreadline-dev zlib1g-dev \
  # Required for some of the ruby gems that will be installed
  libyaml-dev libncurses5-dev libffi-dev libgdbm-dev \
  && \
  apt-get clean &&\
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# plugin site
ARG BLOBXFER_VERSION=1.11.0
# hadolint ignore=DL3018
RUN pip3 install --no-cache-dir blobxfer=="${BLOBXFER_VERSION}" && blobxfer --version

ARG CST_VERSION=1.11.0
# ARG CST_SHASUM_256="72deeea26c990274725a325cf14acd20b8404251c4fcfc4d34b7527aac6c28bc"
RUN curl --silent --show-error --location --output /usr/local/bin/container-structure-test \
  "https://storage.googleapis.com/container-structure-test/v${CST_VERSION}/container-structure-test-linux-amd64" \
  # && sha256sum /usr/local/bin/container-structure-test | grep -q "${CST_SHASUM_256}" \
  && chmod a+x /usr/local/bin/container-structure-test \
  && container-structure-test version

ARG HADOLINT_VERSION=2.10.0
# ARG HADOLINT_SHASUM_256="5099a932032f0d2c708529fb7739d4b2335d0e104ed051591a41d622fe4e4cc4"
RUN curl --silent --show-error --location --output /usr/local/bin/hadolint \
  "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64" \
  # && sha256sum /usr/local/bin/hadolint | grep -q "${HADOLINT_SHASUM_256}" \
  && chmod a+x /usr/local/bin/hadolint \
  && hadolint -v

ARG GH_VERSION=2.10.1
# ARG GH_SHASUM_256="6df9b0214f352fe62b2998c2d1b9828f09c8e133307c855c20c1924134d3da25"
RUN curl --silent --show-error --location --output /tmp/gh.tar.gz \
  "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" \
  # && sha256sum /tmp/gh.tar.gz | grep -q "${GH_SHASUM_256}" \
  && tar xvfz /tmp/gh.tar.gz -C /tmp \
  && mv /tmp/gh_${GH_VERSION}_linux_amd64/bin/gh /usr/local/bin/gh \
  && chmod a+x /usr/local/bin/gh \
  && gh --help

ARG NETLIFY_DEPLOY=0.1.4
RUN mkdir -p /tmp/netlify && \
  curl --silent --show-error --location --output /tmp/netlify.tar.gz \
  "https://github.com/halkeye/netlify-golang-deploy/releases/download/v${NETLIFY_DEPLOY}/netlify-golang-deploy_${NETLIFY_DEPLOY}_Linux_x86_64.tar.gz" \
  && tar xvfz /tmp/netlify.tar.gz -C /tmp/netlify \
  && mv /tmp/netlify/netlify-golang-deploy /usr/local/bin/netlify-deploy \
  && chmod a+x /usr/local/bin/netlify-deploy \
  && rm -rf /tmp/netlify /tmp/netlify.tar.gz \
  && netlify-deploy --help

COPY --from=jx-release-version /usr/bin/jx-release-version /usr/bin/jx-release-version

## Repeating the ARGs from top level to allow them on this scope
# Ref - https://docs.docker.com/engine/reference/builder/#scope
ARG IMG_VERSION=0.5.11
ARG JX_RELEASE_VERSION=2.5.2
ARG JENKINS_AGENT_VERSION=4.13-2
ARG ASDF_VERSION=0.8.1

LABEL io.jenkins-infra.tools="img,container-structure-test,git,make,hadolint,gh,nodejs,npm,blobxfer,jx-release-version,jenkins-agent,netlify-deploy"
LABEL io.jenkins-infra.tools.container-structure-test.version="${CST_VERSION}"
LABEL io.jenkins-infra.tools.img.version="${IMG_VERSION}"
LABEL io.jenkins-infra.tools.blobxfer.version="${BLOBXFER_VERSION}"
LABEL io.jenkins-infra.tools.hadolint.version="${HADOLINT_VERSION}"
LABEL io.jenkins-infra.tools.gh.version="${GH_VERSION}"
LABEL io.jenkins-infra.tools.jx-release-version.version="${JX_RELEASE_VERSION}"
LABEL io.jenkins-infra.tools.jenkins-agent.version="${JENKINS_AGENT_VERSION}"
LABEL io.jenkins-infra.tools.netlify-deploy.version="${NETLIFY_DEPLOY}"

ARG USER=jenkins
ENV XDG_RUNTIME_DIR=/run/${USER}/1000

RUN mkdir -p "${XDG_RUNTIME_DIR}" \
  && chown -R "${USER}" "${XDG_RUNTIME_DIR}" \
  && echo "${USER}":100000:65536 | tee /etc/subuid | tee /etc/subgid

COPY --from=img /usr/bin/img /usr/bin/img
COPY --from=img /usr/bin/newuidmap /usr/bin/newuidmap
COPY --from=img /usr/bin/newgidmap /usr/bin/newgidmap

COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod a+x /usr/local/bin/entrypoint.sh

USER "${USER}"
ENV USER=${USER}
ENV HOME=/home/"${USER}"

RUN bash -c "git clone https://github.com/asdf-vm/asdf.git $HOME/.asdf --branch v${ASDF_VERSION} && \
  echo 'legacy_version_file = yes' > $HOME/.asdfrc && \
  printf 'yarn\njsonlint' > $HOME/.default-npm-packages && \
  . $HOME/.asdf/asdf.sh && \
  asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git && \
  asdf install ruby 2.6.9 && \
  asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git && \
  asdf install nodejs 16.13.1"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
