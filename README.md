# Wine + Python containers

This repository builds Docker images that run the Windows releases of Python on Linux under 64-bit Wine.

The `Makefile` lists the supported versions, from 2.7.18 to 3.15.0. For each minor version it uses the newest release with Windows installers.

## Building the images

The `Makefile` builds two images for each version.

### Runtime image

Runs Python:

```bash
make image-3.15.0
make all-image
```

### Dev image

Adds the mingw-w64 compiler and the Python headers, for building C extensions:

```bash
make dev-3.15.0
make all-dev
```

## Usage

### Check the Python version

```bash
docker run --rm wine-python:3.15.0 -c "import sys; print(sys.version)"
```

### Build an extension

The `hello` directory holds an example C extension. Build and test it in the dev image, for one version or for all of them:

```bash
make test-3.15.0
make -j4 test-all
```

`-j4` runs four versions at a time.

### Open a shell

```bash
make shell-3.15.0
```

## How Python is installed

The build installs every version from python.org's MSI files, using `msiextract`.

- Before 3.5, each release has one MSI with every feature. The build deletes the docs, Tcl/Tk, IDLE and the test suite, so these versions match the later ones.
- From 3.5, the build downloads the full installer (`python-<version>-amd64.exe`). It takes the core, exe, lib and dev MSIs from inside it.

The build checks each installer's signature before using it:

- 2.7 to 3.13: PGP, against the Windows release signing keys.
- 3.14 onwards: Sigstore. Python stopped publishing PGP signatures in 3.14 (PEP 761).

## Image settings

- `WINEPREFIX` is `/wineprefix`.
- `WINEDEBUG` is `-all`, which turns off Wine's debug messages.
- Wine's graphics driver is `null`, as the images have no display.
- `/usr/lib/wine` is on `PATH`, so `wine64` and `wineserver` work in a shell.
- The standard library is compiled to bytecode during the build, so containers don't compile it on each run.

During the build only, `WINEDLLOVERRIDES` turns off `mscoree` and `mshtml`. This stops Wine offering to install Mono and Gecko, which would hang the build.
