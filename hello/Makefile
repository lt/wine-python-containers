# This Makefile is intended to be run inside the wine-python-dev container.

PYTHON_DIR = /wineprefix/drive_c/python
CC = x86_64-w64-mingw32-gcc
CFLAGS = -I$(PYTHON_DIR)/include -shared -O2 -Wall
LDFLAGS = -L$(PYTHON_DIR) -L$(PYTHON_DIR)/libs -lpython -static-libgcc

all: hello.pyd

hello.pyd: hello.c
	$(CC) $(CFLAGS) -o hello.pyd hello.c $(LDFLAGS)

test: hello.pyd
	/usr/lib/wine/wine64 /wineprefix/drive_c/python/python.exe test_hello.py

clean:
	rm -f hello.pyd
