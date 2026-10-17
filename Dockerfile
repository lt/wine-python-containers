ARG PYTHON_VERSION=3.15.0

# Shared by every stage, so the builder and the images run the same Wine build.
FROM debian:trixie-slim AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/lib/wine:$PATH"
ENV WINEARCH=win64
ENV WINEPREFIX=/wineprefix
ENV WINEDEBUG=-all
ENV PYTHONIOENCODING=utf-8

# Debian ships Wine's PE builtins with full DWARF debug info. Stripping it saves
# ~480MB. Wine recognises builtins by a marker in the DOS stub, which strip keeps.
RUN apt-get update && apt-get install -y --no-install-recommends \
    wine64 \
    binutils \
    && strip --strip-debug /usr/lib/x86_64-linux-gnu/wine/x86_64-windows/* \
    && apt-get purge -y --auto-remove binutils \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m wineuser

# -----------------------------------------------------------------------------

FROM base AS builder

ENV WINEDLLOVERRIDES="mscoree,mshtml=d"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    cabextract \
    cosign \
    gnupg \
    msitools \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN install -d -o wineuser -g wineuser "$WINEPREFIX"

USER wineuser
WORKDIR /home/wineuser

# The null graphics driver stops Wine probing for X11 and Wayland on every start.
RUN wine64 wineboot --init && \
    wine64 reg add 'HKCU\Software\Wine\Drivers' /v Graphics /d null /f && \
    wineserver -w

# wineboot copies Wine's PE builtins into the prefix. Replace each identical copy
# with a symlink to the original. This is cached globally for all Python versions.
RUN BUILTINS=/usr/lib/x86_64-linux-gnu/wine/x86_64-windows && \
    find "$WINEPREFIX/drive_c" -type f | while read -r f; do \
        b="$BUILTINS/${f##*/}"; \
        if [ -f "$b" ] && cmp -s "$f" "$b"; then ln -sf "$b" "$f"; fi; \
    done

# Windows release signing keys:
# - Martin v. Löwis (3.0-3.4): CBC547978A3964D14B9AB36A6AF053F07D9DC8D2
# - Steve Dower (2.7.18, 3.5-3.13): 7ED10B6531D7C8E1BC296021FC624643487034E5
RUN gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys \
    CBC547978A3964D14B9AB36A6AF053F07D9DC8D2 \
    7ED10B6531D7C8E1BC296021FC624643487034E5

ARG PYTHON_VERSION

# Every version installs from MSIs. Pre-3.5 releases ship a single MSI. Later
# releases ship a bundle installer with the component MSIs embedded.
RUN set -eu; \
    MAJOR=${PYTHON_VERSION%%.*}; \
    MINOR=${PYTHON_VERSION#*.}; MINOR=${MINOR%%.*}; \
    URL="https://www.python.org/ftp/python/$PYTHON_VERSION"; \
    if [ "$MAJOR" -eq 2 ] || [ "$MINOR" -lt 5 ]; then \
        INSTALLER="python-$PYTHON_VERSION.amd64.msi"; \
    else \
        INSTALLER="python-$PYTHON_VERSION-amd64.exe"; \
    fi; \
    wget -q "$URL/$INSTALLER"; \
    if [ "$MAJOR" -eq 2 ] || [ "$MINOR" -lt 14 ]; then \
        wget -q "$URL/$INSTALLER.asc"; \
        gpg --batch --verify "$INSTALLER.asc" "$INSTALLER"; \
    else \
        # 3.14+: No PGP signatures (PEP 761). Hugo van Kemenade, release
        # manager for 3.14 and 3.15, signs with Sigstore.
        wget -q "$URL/$INSTALLER.sigstore"; \
        cosign verify-blob --new-bundle-format --bundle "$INSTALLER.sigstore" \
            --certificate-identity hugo@python.org \
            --certificate-oidc-issuer https://github.com/login/oauth \
            "$INSTALLER"; \
    fi; \
    if [ "${INSTALLER##*.}" = exe ]; then \
        # The bundle's manifest, extracted as "0", maps each MSI to its payload file
        cabextract -q -d bundle "$INSTALLER"; \
        MSIS=""; \
        for c in core exe lib dev; do \
            SRC=$(grep -o '<Payload [^>]*>' bundle/0 | grep "FilePath=\"$c.msi\"" | head -n 1 | sed 's/.*SourcePath="\([^"]*\)".*/\1/'); \
            MSIS="$MSIS bundle/$SRC"; \
        done; \
    else \
        MSIS="$INSTALLER"; \
    fi; \
    DEST="$WINEPREFIX/drive_c/python"; \
    mkdir -p "$DEST"; \
    for m in $MSIS; do msiextract -C "$DEST" "$m" > /dev/null; done; \
    if [ "${INSTALLER##*.}" = msi ]; then \
        # The single MSI installs every feature. Remove those that the core,
        # exe, lib and dev MSIs leave out.
        (cd "$DEST" && rm -rf Doc Tools tcl Lib/test Lib/idlelib Lib/lib-tk Lib/tkinter Lib/turtledemo \
            DLLs/_tkinter.pyd DLLs/tcl*.dll DLLs/tk*.dll DLLs/_test*.pyd DLLs/_ctypes_test.pyd); \
    fi; \
    rm -rf bundle "$INSTALLER" "$INSTALLER".*

# Containers start with an empty bytecode cache, so every run would recompile
# the stdlib modules it imports. Compile them once here. Test directories are
# skipped: up to 3.11, lib2to3's test data holds files with deliberate syntax
# errors.
RUN wine64 "$WINEPREFIX/drive_c/python/python.exe" -m compileall -q -x '[\\/]tests?[\\/]' 'C:\python\Lib' > /dev/null

# -----------------------------------------------------------------------------

FROM base AS runtime

COPY --from=builder --chown=wineuser:wineuser /wineprefix /wineprefix

USER wineuser
WORKDIR /wineprefix

ENTRYPOINT ["/usr/lib/wine/wine64", "/wineprefix/drive_c/python/python.exe"]

# -----------------------------------------------------------------------------

FROM runtime AS dev

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    mingw-w64 \
    mingw-w64-tools \
    binutils-mingw-w64-x86-64 \
    gcc-mingw-w64-x86-64 \
    g++-mingw-w64-x86-64 \
    make \
    && rm -rf /var/lib/apt/lists/*

ENV CC=x86_64-w64-mingw32-gcc
ENV CXX=x86_64-w64-mingw32-g++

ARG PYTHON_VERSION

# Generate an import library so extensions can link with -lpython. The exact
# DLL name matters: 3.15 also ships python3t.dll, a free-threaded ABI shim.
RUN MAJOR=${PYTHON_VERSION%%.*} && \
    MINOR=${PYTHON_VERSION#*.} && MINOR=${MINOR%%.*} && \
    PYTHON_DLL="python$MAJOR$MINOR.dll" && \
    PYTHON_DLL_PATH=$(find "$WINEPREFIX/drive_c" -name "$PYTHON_DLL" | head -n 1) && \
    test -n "$PYTHON_DLL_PATH" && \
    cd /tmp && \
    gendef "$PYTHON_DLL_PATH" && \
    x86_64-w64-mingw32-dlltool -d "${PYTHON_DLL%.dll}.def" -l /usr/x86_64-w64-mingw32/lib/libpython.a -D "$PYTHON_DLL" && \
    rm "${PYTHON_DLL%.dll}.def"

USER wineuser
