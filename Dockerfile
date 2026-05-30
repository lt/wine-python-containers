FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV WINEARCH=win64
ENV WINEPREFIX=/wineprefix
ENV WINEDEBUG=-all
ENV WINEDLLOVERRIDES="mscoree,mshtml=d"

RUN apt-get update && apt-get install -y --no-install-recommends \
    wine \
    wine64 \
    wget \
    ca-certificates \
    msitools \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /wineprefix && wine wineboot --init && wineserver -w

# Replace physical files in system32 with symlinks to the internal Wine library.
# This saves ~600MB and is cached globally for all Python versions.
RUN cd "$WINEPREFIX/drive_c/windows/system32" && \
    for f in *.dll; do \
        if [ -f "/usr/lib/x86_64-linux-gnu/wine/x86_64-windows/$f" ]; then \
            ln -sf "/usr/lib/x86_64-linux-gnu/wine/x86_64-windows/$f" "$f"; \
        fi; \
    done && \
    wineserver -w

# Public keys for Python release managers:
# - Benjamin Peterson (2.7, 3.1): 12EF3DC38047DA382D18A5B999CDEA9DA4135B38
# - Barry Warsaw (3.0): A2C794A92F2D9AD419F37950DF9B9C731F2A99B1
# - Georg Brandl (3.2): 26014C92F37240F9E347A22A7091B072D963F72B
# - Larry Hastings (3.3, 3.4, 3.5): 97FC712E4C024BBEA48A61ED3A5CA953F73C700D
# - Ned Deily (3.6, 3.7): 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D
# - Łukasz Langa (3.8, 3.9): E3FF285672FAD07303D88F626479256114103102
# - Pablo Galindo Salgado (3.10, 3.11): A035C8C19219BA865442EB0C4C6E1EF060144985
# - Thomas Wouters (3.12, 3.13): E3EDEB8B896857236C03D35AA821E680E5FA6305
# - Martin von Löwis (Windows binaries): 6AF053F07D9DC8D2
# - Steve Dower (Windows binaries): FC624643487034E5
RUN gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys \
    12EF3DC38047DA382D18A5B999CDEA9DA4135B38 \
    A2C794A92F2D9AD419F37950DF9B9C731F2A99B1 \
    26014C92F37240F9E347A22A7091B072D963F72B \
    97FC712E4C024BBEA48A61ED3A5CA953F73C700D \
    0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D \
    E3FF285672FAD07303D88F626479256114103102 \
    A035C8C19219BA865442EB0C4C6E1EF060144985 \
    E3EDEB8B896857236C03D35AA821E680E5FA6305 \
    6AF053F07D9DC8D2 \
    FC624643487034E5

ARG PYTHON_VERSION=3.12.8

RUN mkdir -p "$WINEPREFIX/drive_c/python" && \
    MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1) && \
    MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2) && \
    if [ "$MAJOR" -eq 2 ] || { [ "$MAJOR" -eq 3 ] && [ "$MINOR" -lt 5 ]; }; then \
        # Pre-3.5: Monolithic MSI
        URL="https://www.python.org/ftp/python/$PYTHON_VERSION/python-$PYTHON_VERSION.amd64.msi" && \
        wget -q "$URL" -O installer.msi && \
        wget -q "$URL.asc" -O installer.msi.asc && \
        gpg --batch --verify installer.msi.asc installer.msi && \
        msiextract -C "$WINEPREFIX/drive_c/python" installer.msi && \
        rm installer.msi*; \
    else \
        # 3.5+: Component MSIs
        for c in core exe lib dev; do \
            URL="https://www.python.org/ftp/python/$PYTHON_VERSION/amd64/${c}.msi" && \
            wget -q "$URL" -O "${c}.msi" && \
            if [ "$MAJOR" -eq 3 ] && [ "$MINOR" -lt 14 ]; then \
                wget -q "$URL.asc" -O "${c}.msi.asc" && \
                gpg --batch --verify "${c}.msi.asc" "${c}.msi" && \
                rm "${c}.msi.asc"; \
            else \
                # TODO: Verify component MSIs for 3.14+ using Sigstore (PEP 761)
                : ; \
            fi && \
            msiextract -C "$WINEPREFIX/drive_c/python" "${c}.msi" && \
            rm "${c}.msi"; \
        done; \
    fi

# -----------------------------------------------------------------------------

FROM debian:bookworm-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV WINEPREFIX=/wineprefix
ENV WINEARCH=win64
ENV WINEDEBUG=-all
ENV PYTHONIOENCODING=utf-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    wine64 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m wineuser && mkdir -p /wineprefix && chown wineuser:wineuser /wineprefix

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

RUN case "$PYTHON_VERSION" in \
        2.*|3.[012]*) MSVC_DLL="msvcr90.dll"  ;; \
        3.3*|3.4*)    MSVC_DLL="msvcr100.dll" ;; \
        *)            MSVC_DLL="vcruntime140.dll" ;; \
    esac && \
    cd "$WINEPREFIX/drive_c/windows/system32" && \
    gendef "$MSVC_DLL" && \
    x86_64-w64-mingw32-dlltool -d "${MSVC_DLL%.dll}.def" -l "/usr/x86_64-w64-mingw32/lib/lib${MSVC_DLL%.dll}.a" -D "$MSVC_DLL" && \
    PYTHON_DLL_PATH=$(find "$WINEPREFIX/drive_c/windows/system32" "$WINEPREFIX/drive_c/python" -name "python*.dll" | grep -vE "/python3\.dll$" | head -n 1) && \
    PYTHON_DLL=$(basename "$PYTHON_DLL_PATH") && \
    cd $(dirname "$PYTHON_DLL_PATH") && \
    gendef "$PYTHON_DLL" && \
    x86_64-w64-mingw32-dlltool -d "${PYTHON_DLL%.dll}.def" -l "/usr/x86_64-w64-mingw32/lib/libpython.a" -D "$PYTHON_DLL"

USER wineuser
