# Wine + Python Containers

This repository provides minimal, reproducible environments for running various Windows Python versions on Linux using Wine 64-bit.

## Building the Images

One of two different Dockerfiles are used depending on the Python installer type (MSI or zip).

### Python 2.7 and 3.0 - 3.4 (MSI)

These versions use `Dockerfile.msi.build`.

```bash
# Build Python 2.7.18
docker build -f Dockerfile.msi.build -t wine-python:2.7.18 .

# Build Python 3.4.4
docker build -f Dockerfile.msi.build --build-arg PYTHON_VERSION=3.4.4 -t wine-python:3.4.4 .
```

### Python 3.5 - 3.14 (zip)

These versions use `Dockerfile.zip.build`

```bash
# Build Python 3.13.13 (Default)
docker build -f Dockerfile.zip.build -t wine-python:3.13.13 .

# Build Python 3.8.10
docker build -f Dockerfile.zip.build --build-arg PYTHON_VERSION=3.8.10 -t wine-python:3.8.10 .
```

## Usage

### Basic Verification
Run a simple command to verify the Python version:

```bash
docker run --rm wine-python:3.12.8 -c "import sys; print(sys.version)"
```

## Environment

- WINEPREFIX set to `/wineprefix`.
- WINEDEBUG set to `-all` to keep output clean.
- WINEDLLOVERRIDES disables `mscoree` and `mshtml` to prevent hangs during the build.
