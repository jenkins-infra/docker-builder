# We need the official img image to retrieve the img and new*idmap binaries
ARG IMG_VERSION=0.5.11
FROM r.j3ss.co/img:v${IMG_VERSION} AS img

# Alpine is used by default for fast and ligthweight customization with a fixed minor to benefit of the latest patches
FROM alpine:3.12
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
  pigz=~2.4

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG CST_VERSION=1.10.0
RUN curl --silent --show-error --location --output /usr/local/bin/container-structure-test \
   "https://storage.googleapis.com/container-structure-test/v${CST_VERSION}/container-structure-test-linux-amd64" \
  && sha256sum /usr/local/bin/container-structure-test | grep -q 72deeea26c990274725a325cf14acd20b8404251c4fcfc4d34b7527aac6c28bc \
  && chmod a+x /usr/local/bin/container-structure-test \
  && container-structure-test version

ARG HADOLINT_VERSION=1.19.0
RUN curl --silent --show-error --location --output /usr/local/bin/hadolint \
   "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64" \
  && sha256sum /usr/local/bin/hadolint | grep -q 5099a932032f0d2c708529fb7739d4b2335d0e104ed051591a41d622fe4e4cc4 \
  && chmod a+x /usr/local/bin/hadolint \
  && hadolint -v

LABEL io.jenkins-infra.tools="img,container-structure-test,git,make,hadolint"
LABEL io.jenkins-infra.tools.container-structure-test.version="${CST_VERSION}"
LABEL io.jenkins-infra.tools.img.version="${IMG_VERSION}"
LABEL io.jenkins-infra.tools.hadolint.version="${HADOLINT_VERSION}"

RUN adduser -D -u 1000 user \
  && mkdir -p /run/user/1000 \
  && chown -R user /run/user/1000 /home/user \
  && echo user:100000:65536 | tee /etc/subuid | tee /etc/subgid

COPY --from=img /usr/bin/img /usr/bin/img
COPY --from=img /usr/bin/newuidmap /usr/bin/newuidmap
COPY --from=img /usr/bin/newgidmap /usr/bin/newgidmap

USER user
ENV USER=user
ENV HOME=/home/user
ENV XDG_RUNTIME_DIR=/run/user/1000

CMD ["/bin/bash"]
WORKDIR "/app"
