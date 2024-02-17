#!/bin/zsh

# Latest GoLang version

# URL of the GoLang releases JSON page
url="https://go.dev/dl/?mode=json"

# Use curl to fetch the JSON data and jq to parse it
latest_version=$(curl -s $url | jq -r '.[0].version' | tr -d go)
latest_version_sha256=$(curl -s $url | jq -r '.[0].files[] | select(.os=="linux" and .arch=="amd64" and .kind=="archive") | .sha256')

# Print the results
echo "GO_VERSION=\"$latest_version\""
echo "GO_SHA=\"$latest_version_sha256\""


# Latest GoReleaser version

# GitHub API URL for the latest GoReleaser release
url="https://api.github.com/repos/goreleaser/goreleaser/releases/latest"

# Use curl to fetch the JSON data and jq to parse it
latest_version=$(curl -s $url | jq -r '.tag_name' | tr -d v)
checksums_url=$(curl -s $url | jq -r '.assets[] | select(.name == "checksums.txt") | .browser_download_url')

# Print the version
echo "GORELEASER_VERSION=\"$latest_version\""

# Download and extract the first SHA256 checksum for the Linux x86_64 version
if [ -n "$checksums_url" ]; then
    sha=$(curl -sL "$checksums_url" | grep 'goreleaser_Linux_x86_64.tar.gz' | head -1 | awk '{print $1}')
    echo "GORELEASER_SHA=\"$sha\""
else
    echo "Checksums file URL not found." > /dev/stderr
fi

# Latest TagLib version
# GitHub repository in the format OWNER/REPO
REPO="taglib/taglib"

# GitHub API URL for fetching tags
API_URL="https://api.github.com/repos/$REPO/tags"

# Use curl to fetch the latest tag information from GitHub API
# Use jq to parse the JSON and extract tag name and commit sha
LATEST_TAG_INFO=$(curl -s $API_URL | jq -r '.[0] | {tag_name: .name, sha: .commit.sha}')

if [ -z "$LATEST_TAG_INFO" ]; then
    echo "Failed to fetch the latest tag information."
    exit 1
fi

# Extracting tag name and sha
TAG_NAME=$(echo "$LATEST_TAG_INFO" | jq -r '.tag_name' | tr -d v)
SHA=$(echo "$LATEST_TAG_INFO" | jq -r '.sha')

echo "TAGLIB_VERSION=\"$TAG_NAME\""
echo "TAGLIB_SHA=\"$SHA\""
