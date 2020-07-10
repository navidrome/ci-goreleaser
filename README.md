# Navidrome CI-GoReleaser

![GoLang](https://img.shields.io/badge/Go-1.14.3-brightgreen)
![Goreleaser](https://img.shields.io/badge/Goreleaser-0.135.0-brightgreen)

Docker image used to generate Navidrome's binaries.

**NOTE:** If you want to install [Navidrome](https://www.navidrome.org), please read the [documentation](https://www.navidrome.org/docs/installation/). **Don't try to use the images from this repository!**

## Usage

The version represents the Go version + a counter. So if the Go version is `1.13.7` and this is
the first release based on that, the version should be `1.13.7-1`

### Manual release

```bash
version=1.13.7-1 make install
```

This will build the image in the local workstation, tag and push the image.

## macOS

The macOS part of the build requires the macOS SDK.

To obtain it, register for a developer account, then download `Xcode_8.3.3.xip` from :

https://developer.apple.com/download/more/

Unpack the downloaded xip file in the ~/Downloads folder and run `create_osx_sdk.sh` to create the MacOSX10.12.sdk tarfile. 
You can delete downloaded xip and the `Xcode` files after the tarfile is created.

## Credits:

Based on https://github.com/bep/dockerfiles
