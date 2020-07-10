
user=deluan
repo=ci-goreleaser

version ?= latest

latest:
	docker build -t ${user}/${repo}:latest .
.PHONY: latest

build: check-version
	docker build -t ${user}/${repo}:${version} -t ${user}/${repo}:latest .
.PHONY: build

build-no-cache: check-version
	docker build --no-cache -t ${user}/${repo}:${version} -t ${user}/${repo}:latest .
.PHONY: build-no-cache

check-version:
	@if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\-[0-9]+.* ]]; then echo "Usage: version=X.X.X-X make "; exit 1; fi
.PHONY: check-version

install: build
	docker push ${user}/${repo}:${version}
	docker push ${user}/${repo}:latest
.PHONY: install

get-tags:
	@wget -q https://registry.hub.docker.com/v1/repositories/deluan/ci-goreleaser/tags -O - | jq -r '.[].name' | grep "^1" | sort -r
.PHONY: get-tags
