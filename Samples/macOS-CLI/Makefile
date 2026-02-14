build-cli-with-binary:
	@echo "Building cli-with-binary..."
	swift build --product cli-with-binary
	
exec-sandboxed-cli-with-binary: build-cli-with-binary
	sandbox-exec -f sandbox.sb -- .build/arm64-apple-macosx/debug/cli-with-binary

build-cli-with-spm:
	@echo "Building cli-with-spm..."
	swift build --product cli-with-spm
	
exec-sandboxed-cli-with-spm: build-cli-with-spm
	sandbox-exec -f sandbox.sb -- .build/arm64-apple-macosx/debug/cli-with-spm
