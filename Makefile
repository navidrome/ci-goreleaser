include .versions

user=deluan
repo=ci-goreleaser

version ?= latest

dev:
	docker build --build-arg GO_VERSION=${GO_VERSION} \
		--build-arg GO_SHA=${GO_SHA} \
		--build-arg GORELEASER_VERSION=${GORELEASER_VERSION} \
		--build-arg GORELEASER_SHA=${GORELEASER_SHA} \
		--build-arg TAGLIB_VERSION=${TAGLIB_VERSION} \
		--build-arg TAGLIB_SHA=${TAGLIB_SHA} \
		--platform linux/amd64 -t ${user}/${repo}:dev .
.PHONY: dev

latest: dev
	docker tag ${user}/${repo}:dev ${user}/${repo}:latest
.PHONY: latest

build: check-version latest
	docker tag ${user}/${repo}:latest ${user}/${repo}:${version}
.PHONY: build

check-version:
	@if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\-[0-9]+.* ]]; then echo "Usage: version=X.X.X-X make $(MAKECMDGOALS)"; exit 1; fi
.PHONY: check-version

release: build
	docker push ${user}/${repo}:${version}
	docker push ${user}/${repo}:latest
.PHONY: release

update-versions:
	./latest-versions.sh > .versions
	git diff .versions
.PHONY: update-versions

get-tags:
	@wget -q https://registry.hub.docker.com/v1/repositories/deluan/ci-goreleaser/tags -O - | jq -r '.[].name' | grep "^1" | sort -r
.PHONY: get-tags

latest-tag:
	@make get-tags | head -1
.PHONY: latest-tag
