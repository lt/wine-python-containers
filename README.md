# Wine + Python Containers

This repository provides minimal, reproducible environments for running various Windows Python versions on Linux using Wine 64-bit.

Supported versions are listed in the `Makefile`, from 2.7.18 to 3.15.0. Each is the last release of its series with Windows binaries, or the latest one if the series is still maintained.

## Building the Images

A `Makefile` is provided to simplify building runtime and development images across all supported versions.

### Runtime Images
Minimal image for executing code:

```bash
make image-3.15.0
make all-image
```

### Development Images
Image with `mingw-w64` and Python headers for compiling extensions:

```bash
make dev-3.15.0
make all-dev
```

## Usage

### Basic Verification
Run a simple command to verify the Python version:

```bash
docker run --rm wine-python:3.15.0 -c "import sys; print(sys.version)"
```

### Extension Development
An example extension is provided in the `hello` directory.

Compile and test the C extension inside the dev container:

```bash
make test-3.15.0
```

### Interactive Shell
Open a shell in the development environment:

```bash
make shell-3.15.0
```

## Environment

- WINEPREFIX set to `/wineprefix`.
- WINEDEBUG set to `-all` to keep output clean.
- WINEDLLOVERRIDES disables `mscoree` and `mshtml` to prevent hangs during the build.
- Wine's graphics driver is set to `null`, as the images are headless.
- `/usr/lib/wine` is on `PATH`, so `wine64` and `wineserver` work in a shell.
