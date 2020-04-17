# Navidrome CI-GoReleaser

![Docker](https://github.com/navidrome/ci-goreleaser/workflows/Docker/badge.svg)

Docker image used to generate Navidrome's binaries.

**NOTE:** If you want to install [Navidrome](https://www.navidrome.org), please read the [documentation](https://www.navidrome.org/docs/installation/). **Don't try to use the images from this repository!**

## Usage

The version represents the Go version + a counter. So if the Go version is `1.13.7` and this is
the first release based on that, the version should be `1.13.7-1`

### Automated release

```bash
$ make release V=1.13.17-1
```

This will trigger a GitHub action that will build and publish the Docker image, tagged with the
especified version

### Manual release

```bash
version=1.13.7-1 make install
```

This will build the image in the local workstation, tag and push the image.

## macOS

The macOS part of the build requires the macOS SDK.

To obtain it, register for a developer account, then download Xcode:

https://download.developer.apple.com/Developer_Tools/Xcode_8.3.3/Xcode8.3.3.xip

Using macOS, you can mount the dmg and create the SDK tarfile with `create_osx_sdk.sh`.

## Credits:

Based on https://github.com/bep/dockerfiles
