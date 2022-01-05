# The official img's image is required to retrieve the img and new*idmap binaries
ARG IMG_VERSION=0.5.11
ARG JX_RELEASE_VERSION=2.5.1
ARG JENKINS_AGENT_VERSION=4.11.2-2
ARG ASDF_VERSION=0.8.1

FROM ghcr.io/jenkins-x/jx-release-version:${JX_RELEASE_VERSION} AS jx-release-version
FROM r.j3ss.co/img:v${IMG_VERSION} AS img

# Alpine is used by default for fast and ligthweight customization with a fixed minor to benefit of the latest patches
FROM jenkins/inbound-agent:${JENKINS_AGENT_VERSION}-alpine-jdk11
USER root
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN apk add --no-cache \
  # Recommended (even though not strictly required) for jenkins agents
  bash=~5 \
  # Used to download binaries (implies the package "ca-certificates" as a dependency)
  curl=~7 \
  # Dev. Tooling packages (e.g. tools provided by this image installable through Alpine Linux Packages)
  git=~2 \
  make=~4 \
  # Required for img's builds
  pigz=~2.6 \
  jq=~1 \
  gcompat=~1

# Stuff to be able to install ruby
# hadolint ignore=DL3018
RUN apk add --no-cache gcc zlib-dev openssl-dev gdbm-dev readline-dev libffi-dev coreutils yaml-dev linux-headers autoconf

# plugin site
ARG BLOBXFER_VERSION=1.11.0
# hadolint ignore=DL3018
RUN apk add --no-cache \
      python3 \
      py3-cryptography \
      py3-pip \
    && apk add --no-cache --virtual build-dependencies \
      build-base \
      libffi-dev \
      libressl-dev \
      gcc \
      python3-dev \
  && pip3 install --no-cache-dir blobxfer=="${BLOBXFER_VERSION}" \
  && blobxfer --version

ARG CST_VERSION=1.11.0
# ARG CST_SHASUM_256="72deeea26c990274725a325cf14acd20b8404251c4fcfc4d34b7527aac6c28bc"
RUN curl --silent --show-error --location --output /usr/local/bin/container-structure-test \
    "https://storage.googleapis.com/container-structure-test/v${CST_VERSION}/container-structure-test-linux-amd64" \
# && sha256sum /usr/local/bin/container-structure-test | grep -q "${CST_SHASUM_256}" \
  && chmod a+x /usr/local/bin/container-structure-test \
  && container-structure-test version

ARG HADOLINT_VERSION=2.8.0
# ARG HADOLINT_SHASUM_256="5099a932032f0d2c708529fb7739d4b2335d0e104ed051591a41d622fe4e4cc4"
RUN curl --silent --show-error --location --output /usr/local/bin/hadolint \
    "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64" \
# && sha256sum /usr/local/bin/hadolint | grep -q "${HADOLINT_SHASUM_256}" \
  && chmod a+x /usr/local/bin/hadolint \
  && hadolint -v

ARG GH_VERSION=2.4.0
# ARG GH_SHASUM_256="6df9b0214f352fe62b2998c2d1b9828f09c8e133307c855c20c1924134d3da25"
RUN curl --silent --show-error --location --output /tmp/gh.tar.gz \
    "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" \
# && sha256sum /tmp/gh.tar.gz | grep -q "${GH_SHASUM_256}" \
  && tar xvfz /tmp/gh.tar.gz -C /tmp \
  && mv /tmp/gh_${GH_VERSION}_linux_amd64/bin/gh /usr/local/bin/gh \
  && chmod a+x /usr/local/bin/gh \
  && gh --help

COPY --from=jx-release-version /usr/bin/jx-release-version /usr/bin/jx-release-version


## Repeating the ARGs from top level to allow them on this scope
# Ref - https://docs.docker.com/engine/reference/builder/#scope
ARG IMG_VERSION=0.5.11
ARG JX_RELEASE_VERSION=2.5.1
ARG JENKINS_AGENT_VERSION=4.11.2-2
ARG ASDF_VERSION=0.8.1

LABEL io.jenkins-infra.tools="img,container-structure-test,git,make,hadolint,gh,nodejs,npm,blobxfer,jx-release-version,jenkins-agent"
LABEL io.jenkins-infra.tools.container-structure-test.version="${CST_VERSION}"
LABEL io.jenkins-infra.tools.img.version="${IMG_VERSION}"
LABEL io.jenkins-infra.tools.blobxfer.version="${BLOBXFER_VERSION}"
LABEL io.jenkins-infra.tools.hadolint.version="${HADOLINT_VERSION}"
LABEL io.jenkins-infra.tools.gh.version="${GH_VERSION}"
LABEL io.jenkins-infra.tools.jx-release-version.version="${JX_RELEASE_VERSION}"
LABEL io.jenkins-infra.tools.jenkins-agent.version="${JENKINS_AGENT_VERSION}"

ARG USER=jenkins
ENV XDG_RUNTIME_DIR=/run/${USER}/1000

RUN mkdir -p "${XDG_RUNTIME_DIR}" \
  && chown -R "${USER}" "${XDG_RUNTIME_DIR}" \
  && echo "${USER}":100000:65536 | tee /etc/subuid | tee /etc/subgid

COPY --from=img /usr/bin/img /usr/bin/img
COPY --from=img /usr/bin/newuidmap /usr/bin/newuidmap
COPY --from=img /usr/bin/newgidmap /usr/bin/newgidmap

# Jenkins.io specifically needs 1.17.3 and multiple versions can be installed
COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod a+x /usr/local/bin/entrypoint.sh

USER "${USER}"
ENV USER=${USER}
ENV HOME=/home/"${USER}"

RUN bash -c "git clone https://github.com/asdf-vm/asdf.git $HOME/.asdf --branch v${ASDF_VERSION} && \
      echo 'legacy_version_file = yes' > $HOME/.asdfrc && \
      . $HOME/.asdf/asdf.sh && \
      asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git && \
      asdf install ruby 2.6.9 && \
      asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git && \
      asdf install nodejs 16.13.1"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
