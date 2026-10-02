.PHONY: test test-symbolication test-viewer

test: test-symbolication test-viewer

test-symbolication:
	/bin/bash tests/symbolicate.test.sh

test-viewer:
	node tests/viewer.test.cjs
