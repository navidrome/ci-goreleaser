
user=deluan
repo=ci-goreleaser

version ?= latest

latest:
	docker build -t ${user}/${repo}:latest .
.PHONY: latest

build:
	docker build -t ${user}/${repo}:${version} -t ${user}/${repo}:latest .
.PHONY: build

build-no-cache:
	docker build --no-cache -t ${user}/${repo}:${version} -t ${user}/${repo}:latest .
.PHONY: build-no-cache

install: build
	docker push ${user}/${repo}:${version}
	docker push ${user}/${repo}:latest
.PHONY: install

release:
	@if [[ ! "${V}" =~ ^[0-9]+\.[0-9]+\.[0-9]+.* ]]; then echo "Usage: make release V=X.X.X"; exit 1; fi
	@if [ -n "`git status -s`" ]; then echo "\n\nThere are pending changes. Please commit or stash first"; exit 1; fi
	git tag v${V}
	git push origin v${V}
.PHONY: release
