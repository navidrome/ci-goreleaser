
user=deluan
repo=ci-goreleaser

version ?= latest

latest:
	docker build --platform linux/amd64 -t ${user}/${repo}:latest .
.PHONY: latest

build: check-version
	docker build --platform linux/amd64 -t ${user}/${repo}:${version} -t ${user}/${repo}:latest .
.PHONY: build

build-no-cache: check-version
	docker build --platform linux/amd64 --no-cache -t ${user}/${repo}:${version} -t ${user}/${repo}:latest .
.PHONY: build-no-cache

check-version:
	@if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\-[0-9]+.* ]]; then echo "Usage: version=X.X.X-X make "; exit 1; fi
.PHONY: check-version

release: build
	docker push ${user}/${repo}:${version}
	docker push ${user}/${repo}:latest
.PHONY: release

get-tags:
	@wget -q https://registry.hub.docker.com/v1/repositories/deluan/ci-goreleaser/tags -O - | jq -r '.[].name' | grep "^1" | sort -r
.PHONY: get-tags

latest-tag:
	@make get-tags | head -1
.PHONY: latest-tag
