BIN_PATH := $(shell swift build --show-bin-path)

build-cli-with-binary:
	@echo "Building cli-with-binary..."
	swift build --product cli-with-binary

exec-sandboxed-cli-with-binary: build-cli-with-binary
	sandbox-exec -f sandbox.sb -- $(BIN_PATH)/cli-with-binary

build-cli-with-spm:
	@echo "Building cli-with-spm..."
	swift build --product cli-with-spm

exec-sandboxed-cli-with-spm: build-cli-with-spm
	sandbox-exec -f sandbox.sb -- $(BIN_PATH)/cli-with-spm
