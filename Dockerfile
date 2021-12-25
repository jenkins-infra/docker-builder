# The official img's image is required to retrieve the img and new*idmap binaries
ARG IMG_VERSION=0.5.11
FROM r.j3ss.co/img:v${IMG_VERSION} AS img

# Alpine is used by default for fast and ligthweight customization with a fixed minor to benefit of the latest patches
FROM alpine:3.13
## Repeating the ARG to add it into the scope of this image
ARG IMG_VERSION=0.5.11
RUN apk add --no-cache \
  # Recommended (even though not strictly required) for jenkins agents
  bash=~5 \
  # Used to download binaries (implies the package "ca-certificates" as a dependency)
  curl=~7 \
  # Dev. Tooling packages (e.g. tools provided by this image installable through Alpine Linux Packages)
  git=~2 \
  make=~4 \
  # Required for img's builds
  pigz=~2.4 \
  jq=~1

## bash need to be installed for this instruction to work as expected
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

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



LABEL io.jenkins-infra.tools="img,container-structure-test,git,make,hadolint,gh"
LABEL io.jenkins-infra.tools.container-structure-test.version="${CST_VERSION}"
LABEL io.jenkins-infra.tools.img.version="${IMG_VERSION}"
LABEL io.jenkins-infra.tools.hadolint.version="${HADOLINT_VERSION}"
LABEL io.jenkins-infra.tools.gh.version="${GH_VERSION}"

ARG UID=1000
ENV USER=infra
ENV HOME=/home/"${USER}"
ENV XDG_RUNTIME_DIR=/run/${USER}/1000

RUN adduser -D -u "${UID}" "${USER}" \
  && mkdir -p "${XDG_RUNTIME_DIR}" \
  && chown -R "${USER}" "${XDG_RUNTIME_DIR}" "${HOME}" \
  && echo "${USER}":100000:65536 | tee /etc/subuid | tee /etc/subgid

COPY --from=img /usr/bin/img /usr/bin/img
COPY --from=img /usr/bin/newuidmap /usr/bin/newuidmap
COPY --from=img /usr/bin/newgidmap /usr/bin/newgidmap

USER "${USER}"

CMD ["/bin/bash"]
WORKDIR "/app"
