# Support Python versions
MSI_VERSIONS = 2.7.18 3.0.1 3.1.4 3.2.5 3.3.5 3.4.4
ZIP_VERSIONS = 3.5.4 3.6.8 3.7.9 3.8.10 3.9.13 3.10.11 3.11.9 3.12.7 3.13.13 3.14.5
ALL_VERSIONS = $(MSI_VERSIONS) $(ZIP_VERSIONS)

IMAGE_NAME = wine-python
DEV_IMAGE_NAME = wine-python-dev

.PHONY: all help test-all clean $(ALL_VERSIONS)

all: help

images-all: $(addprefix image-,$(ALL_VERSIONS))
dev-all: $(addprefix dev-,$(ALL_VERSIONS))

help:
	@echo "Usage: make [target] VERSION=<version>"
	@echo ""
	@echo "Targets:"
	@echo "  image-%    Build runtime image for version % (e.g. make image-3.12.8)"
	@echo "  dev-%      Build development image for version % (e.g. make dev-3.12.8)"
	@echo "  build-%    Compile the extension for version %"
	@echo "  test-%     Run tests for version %"
	@echo "  shell-%    Open an interactive shell in dev environment for version %"
	@echo "  images-all Build all runtime images"
	@echo "  dev-all    Build all development images"
	@echo "  test-all   Run tests across all supported versions"
	@echo "  clean      Remove docker images"

# Determine installer type: msi for 2.x and 3.0-3.4, zip for 3.5+
GET_TYPE = $(shell echo $(1) | awk -F. '{print ($$1 < 3 || ($$1 == 3 && $$2 < 5)) ? "msi" : "zip"}')

# Build runtime image
image-%:
	docker build -f Dockerfile.$(call GET_TYPE,$*).build --target runtime --build-arg PYTHON_VERSION=$* -t $(IMAGE_NAME):$* .

# Build development image
dev-%:
	docker build -f Dockerfile.$(call GET_TYPE,$*).build --target dev --build-arg PYTHON_VERSION=$* -t $(DEV_IMAGE_NAME):$* .

# Compile extension
build-%: dev-%
	docker run --rm --entrypoint /bin/bash -v $(PWD)/hello:/build -w /build $(DEV_IMAGE_NAME):$* -c "make clean hello.pyd"

# Run tests
test-%: dev-%
	docker run --rm --entrypoint /bin/bash -v $(PWD)/hello:/build -w /build $(DEV_IMAGE_NAME):$* -c "make clean all test"

# Interactive shell
shell-%: dev-%
	docker run -it --rm --entrypoint /bin/bash -v $(PWD)/hello:/build -w /build $(DEV_IMAGE_NAME):$*

# Comprehensive test
test-all:
	@for v in $(ALL_VERSIONS); do \
		echo "Testing Python $$v..."; \
		$(MAKE) test-$$v || exit 1; \
	done

clean:
	docker rmi $$(docker images '$(IMAGE_NAME)' -q) 2>/dev/null || true
	docker rmi $$(docker images '$(DEV_IMAGE_NAME)' -q) 2>/dev/null || true
