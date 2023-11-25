#!/bin/zsh

# Latest GoLang version

# URL of the GoLang releases JSON page
url="https://go.dev/dl/?mode=json"

# Use curl to fetch the JSON data and jq to parse it
latest_version=$(curl -s $url | jq -r '.[0].version' | tr -d go)
latest_version_sha256=$(curl -s $url | jq -r '.[0].files[] | select(.os=="linux" and .arch=="amd64" and .kind=="archive") | .sha256')

# Print the results
echo "GO_VERSION=$latest_version"
echo "GO_SHA=$latest_version_sha256"


# Latest GoReleaser version

# GitHub API URL for the latest GoReleaser release
url="https://api.github.com/repos/goreleaser/goreleaser/releases/latest"

# Use curl to fetch the JSON data and jq to parse it
latest_version=$(curl -s $url | jq -r '.tag_name' | tr -d v)
checksums_url=$(curl -s $url | jq -r '.assets[] | select(.name == "checksums.txt") | .browser_download_url')

# Print the version
echo "GORELEASER_VERSION=$latest_version"

# Download and extract the first SHA256 checksum for the Linux x86_64 version
if [ -n "$checksums_url" ]; then
    sha=$(curl -sL "$checksums_url" | grep 'goreleaser_Linux_x86_64.tar.gz' | head -1 | awk '{print $1}')
    echo "GORELEASER_SHA=$sha"
else
    echo "Checksums file URL not found." > /dev/stderr
fi

# Latest TagLib version

# GitHub API URL for the latest TagLib release
url="https://api.github.com/repos/taglib/taglib/releases/latest"

# Use curl to fetch the JSON data and jq to parse it
latest_version=$(curl -s $url | jq -r '.tag_name' | tr -d v)
tarball_url=$(curl -s $url | jq -r '.tarball_url')

# Print the version and tarball URL
echo "TAGLIB_VERSION=$latest_version"
echo "TAGLIB_URL=$tarball_url"

# Optional: Download and compute the SHA256 checksum
if [ -n "$tarball_url" ]; then
  sha=$(curl -sL "$tarball_url" | shasum -a 256 | awk '{print $1}')
  echo "TAGLIB_SHA=$sha"
fi
