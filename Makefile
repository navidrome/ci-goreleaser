
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