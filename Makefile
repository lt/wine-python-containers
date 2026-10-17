# Supported Python versions, grouped by installer type
MSI_VERSIONS = 2.7.18 3.0.1 3.1.4 3.2.5 3.3.5 3.4.4
BUNDLE_VERSIONS = 3.5.4 3.6.8 3.7.9 3.8.10 3.9.13 3.10.11 3.11.9 3.12.10 3.13.16 3.14.8 3.15.0
ALL_VERSIONS = $(MSI_VERSIONS) $(BUNDLE_VERSIONS)

IMAGE_NAME = wine-python
DEV_IMAGE_NAME = wine-python-dev

.PHONY: all help all-image all-dev test-all clean

all: help

all-image: $(addprefix image-,$(ALL_VERSIONS))
all-dev: $(addprefix dev-,$(ALL_VERSIONS))

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  image-%    Build runtime image for version % (e.g. make image-3.15.0)"
	@echo "  dev-%      Build development image for version % (e.g. make dev-3.15.0)"
	@echo "  build-%    Compile the extension for version %"
	@echo "  test-%     Run tests for version %"
	@echo "  shell-%    Open an interactive shell in dev environment for version %"
	@echo "  all-image  Build all runtime images"
	@echo "  all-dev    Build all development images"
	@echo "  test-all   Run tests across all supported versions (parallel with -j)"
	@echo "  clean      Remove docker images"

# Build runtime image
image-%:
	docker build -f Dockerfile --target runtime --build-arg PYTHON_VERSION=$* -t $(IMAGE_NAME):$* .

# Build development image
dev-%:
	docker build -f Dockerfile --target dev --build-arg PYTHON_VERSION=$* -t $(DEV_IMAGE_NAME):$* .

# Compile extension
build-%: dev-%
	docker run --rm --entrypoint /bin/bash -v $(CURDIR)/hello:/build -w /build $(DEV_IMAGE_NAME):$* -c "make clean hello.pyd"

# Run tests. Each version builds in its own copy of hello/, so parallel runs
# don't overwrite each other's hello.pyd.
test-%: dev-%
	docker run --rm --entrypoint /bin/bash -v $(CURDIR)/hello:/src:ro $(DEV_IMAGE_NAME):$* -c "cp -r /src /tmp/build && cd /tmp/build && make clean all test"

# Interactive shell
shell-%: dev-%
	docker run -it --rm --entrypoint /bin/bash -v $(CURDIR)/hello:/build -w /build $(DEV_IMAGE_NAME):$*

# Comprehensive test
test-all: $(addprefix test-,$(ALL_VERSIONS))

clean:
	docker rmi $$(docker images '$(IMAGE_NAME)' -q) 2>/dev/null || true
	docker rmi $$(docker images '$(DEV_IMAGE_NAME)' -q) 2>/dev/null || true
