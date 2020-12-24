
IMAGE_NAME ?= docker-builder
IMAGE_DEPLOY ?= $(IMAGE_NAME)
DOCKERFILE ?= Dockerfile

GIT_COMMIT_REV ?= $(shell git log -n 1 --pretty=format:'%h')
GIT_SCM_URL ?= $(shell git config --get remote.origin.url)
SCM_URI ?= $(subst git@github.com:,https://github.com/,$(GIT_SCM_URL))
BUILD_DATE ?= $(shell date --utc '+%Y-%m-%dT%H:%M:%S')

export GIT_COMMIT_REV GIT_SCM_URL SCM_URI

help: ## Show this Makefile's help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build: ## Build the Docker Image to the local img's cache
	img build \
		-t $(IMAGE_NAME) \
		--build-arg "GIT_COMMIT_REV=$(GIT_COMMIT_REV)" \
		--build-arg "GIT_SCM_URL=$(GIT_SCM_URL)" \
		--build-arg "BUILD_DATE=$(BUILD_DATE)" \
		--label "org.opencontainers.image.source=$(GIT_SCM_URL)" \
		--label "org.label-schema.vcs-url=$(GIT_SCM_URL)" \
		--label "org.opencontainers.image.url=$(SCM_URI)" \
		--label "org.label-schema.url=$(SCM_URI)" \
		--label "org.opencontainers.image.revision=$(GIT_COMMIT_REV)" \
		--label "org.label-schema.vcs-ref=$(GIT_COMMIT_REV)" \
		--label "org.opencontainers.image.created=$(BUILD_DATE)" \
		--label "org.label-schema.build-date=$(BUILD_DATE)" \
		-f $(DOCKERFILE) \
		./

image.tar: build ## Export the built Docker Image as the 'image.tar' archive.
	img save --output=./image.tar $(IMAGE_NAME)

clean: ## Delete any file generated during the build steps
	rm -f ./image.tar

test: image.tar ## Execute the test harness on the 'image.tar' Docker Image.
	container-structure-test test --driver=tar --image=image.tar --config=./cst.yml

## This steps expects that you are logged to the Docker registry to push image into
deploy: ## Tag and push the built image as specified by $(IMAGE_DEPLOY).
	img tag $(IMAGE_NAME) $(IMAGE_DEPLOY)
	img push $(IMAGE_DEPLOY)

.PHONY: all clean build test deploy
