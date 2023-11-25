# Navidrome CI-GoReleaser

![Version](https://img.shields.io/docker/v/deluan/ci-goreleaser?label=Version&sort=semver)
![Goreleaser](https://img.shields.io/badge/Goreleaser-1.22.1-brightgreen)
![TagLib](https://img.shields.io/badge/TagLib-1.13-brightgreen)

Docker image used to generate Navidrome's binaries.

**NOTE:** If you want to install [Navidrome](https://www.navidrome.org), please read the [documentation](https://www.navidrome.org/docs/installation/). **Don't try to use the images from this repository!**

## Usage

The version represents the Go version + a counter. So if the Go version is `1.13.7` and this is
the first release based on that, the version should be `1.13.7-1`. You can check the latest release with `make latest-tag`

### Manual release

```bash
make release version=1.13.7-1 
```

This will build the image in the local workstation, tag and push the image.

## macOS

The macOS part of the build requires the macOS SDK.

If you need to build a different version than it is available in this repo, you can create it with the following instructions:

1) Register for an Apple developer account, then download `Xcode_8.3.3.xip` from: https://developer.apple.com/download/more/
2) Unpack the downloaded xip file in the ~/Downloads folder
3) Run `create_osx_sdk.sh` to create the MacOSX10.12.sdk tarfile. You can delete downloaded xip and the `Xcode` files after the tarfile is created.

## Credits:

Based on https://github.com/bep/dockerfiles
