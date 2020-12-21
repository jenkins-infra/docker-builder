# Alpine is used by default for fast and ligthweight customization with a fixed minor to benefit of the latest patches
FROM alpine:3.12

RUN apk add --no-cache \
  # Recommended (even though not strictly required) for jenkins agents
  bash \
  # Used to download binaries (implies the package "ca-certificates" as a dependency)
  curl \
  # Dev. Tooling packages (e.g. tools provided by this image installable through Alpine Linux Packages)
  make \
  img

### Install Google's container-structure-test CLI
# No checksum provided so no verification (yet?)
ENV CST_VERSION=1.9.1
RUN curl --silent --show-error --location --output /usr/local/bin/container-structure-test \
   "https://storage.googleapis.com/container-structure-test/v${CST_VERSION}/container-structure-test-linux-amd64" \
  && chmod a+x /usr/local/bin/container-structure-test \
  && container-structure-test version

LABEL io.jenkins-infra.tools="img,container-structure-test"
LABEL io.jenkins-infra.tools.container-structure-test.version="${CST_VERSION}"
