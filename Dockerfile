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

### Install Google's container-structure-test CLI
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# No checksum provided so no verification (yet?)
ARG CST_VERSION=1.9.1
RUN curl --silent --show-error --location --output /usr/local/bin/container-structure-test \
   "https://storage.googleapis.com/container-structure-test/v${CST_VERSION}/container-structure-test-linux-amd64" \
  && chmod a+x /usr/local/bin/container-structure-test \
  && container-structure-test version

# No checksum provided so no verification (yet?)
ARG HADOLINT_VERSION=1.19.0
RUN curl --silent --show-error --location --output /usr/local/bin/hadolint \
   "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64" \
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