# Python versions that use the MSI installer
MSI_VERSIONS = 2.7.18 3.0.1 3.1.4 3.2.5 3.3.5 3.4.4

# Python versions that use the embeddable zip distribution
ZIP_VERSIONS = 3.5.4 3.6.8 3.7.9 3.8.10 3.9.13 3.10.11 3.11.9 3.12.7 3.13.13 3.14.5

.PHONY: all build-msi build-zip build $(MSI_VERSIONS) $(ZIP_VERSIONS)

all: build-msi build-zip

# Build a specific version provided via VERSION=x.y.z
build:
	@if [ -z "$(VERSION)" ]; then \
		echo "Please specify a version, e.g., 'make build VERSION=3.12.8'"; \
		exit 1; \
	fi; \
	MAJOR=$$(echo $(VERSION) | cut -d. -f1); \
	MINOR=$$(echo $(VERSION) | cut -d. -f2); \
	if [ "$$MAJOR" -eq 2 ] || { [ "$$MAJOR" -eq 3 ] && [ "$$MINOR" -lt 5 ]; }; then \
		DOCKERFILE=Dockerfile.msi.build; \
	else \
		DOCKERFILE=Dockerfile.zip.build; \
	fi; \
	echo "Building Python $(VERSION) using $$DOCKERFILE..."; \
	docker build -f $$DOCKERFILE --build-arg PYTHON_VERSION=$(VERSION) -t wine-python:$(VERSION) .

build-msi: $(MSI_VERSIONS)
build-zip: $(ZIP_VERSIONS)

$(MSI_VERSIONS):
	$(MAKE) build VERSION=$@

$(ZIP_VERSIONS):
	$(MAKE) build VERSION=$@

clean:
	docker rmi $$(docker images 'wine-python' -q)
