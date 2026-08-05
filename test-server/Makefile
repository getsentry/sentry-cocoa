PORT ?= 8081
PID_FILE := .test-server.pid
LOG_FILE := .test-server.log
TEST_SERVER_EXECUTABLE ?= .build/debug/Run

.PHONY: build
build:
	swift build

.PHONY: test
test:
	swift test

.PHONY: release-arm64
release-arm64:
	swift build -c release --arch arm64
	cp "$(shell swift build --show-bin-path -c release --arch arm64)/Run" test-server-exec

.PHONY: release-universal
release-universal:
	swift build -c release --triple x86_64-apple-macosx
	swift build -c release --arch arm64
	lipo -create -output test-server-exec "$(shell swift build --show-bin-path -c release --triple x86_64-apple-macosx)/Run" "$(shell swift build --show-bin-path -c release --arch arm64)/Run"

.PHONY: start-debug
start-debug: build start

.PHONY: start
start:
	@if [ ! -x "$(TEST_SERVER_EXECUTABLE)" ]; then \
		echo "Test-server executable is not executable: $(TEST_SERVER_EXECUTABLE)"; \
		exit 1; \
	fi; \
	if [ -f "$(PID_FILE)" ]; then \
		pid=$$(cat "$(PID_FILE)"); \
		if kill -0 "$$pid" 2>/dev/null; then \
			echo "Test server is already running with PID $$pid"; \
			exit 1; \
		fi; \
		rm "$(PID_FILE)"; \
	fi; \
	nohup "$(abspath $(TEST_SERVER_EXECUTABLE))" serve --port "$(PORT)" > "$(LOG_FILE)" 2>&1 & \
	pid=$$!; \
	echo "$$pid" > "$(PID_FILE)"; \
	for _ in $$(seq 1 200); do \
		if ! kill -0 "$$pid" 2>/dev/null; then \
			rm -f "$(PID_FILE)"; \
			echo "Test server exited before becoming ready. See $(LOG_FILE) for details."; \
			exit 1; \
		fi; \
		if [ "$$(curl --fail --silent "http://localhost:$(PORT)/health")" = "OK" ]; then \
			echo "Test server is running at http://localhost:$(PORT) with PID $$pid"; \
			exit 0; \
		fi; \
		sleep 0.1; \
	done; \
	kill "$$pid" 2>/dev/null || true; \
	rm -f "$(PID_FILE)"; \
	echo "Test server failed to become ready after 20 seconds. See $(LOG_FILE) for details."; \
	exit 1

.PHONY: test-integration
test-integration: build
	@$(MAKE) start
	@trap '$(MAKE) stop' EXIT; \
		test "$$(curl --fail --silent "http://localhost:$(PORT)/health")" = "OK"; \
		test "$$(curl --fail --silent "http://localhost:$(PORT)/")" = "It works!"; \
		test "$$(curl --fail --silent -H "baggage: sentry-trace_id=123" "http://localhost:$(PORT)/echo-baggage-header")" = "sentry-trace_id=123"; \
		test "$$(curl --fail --silent "http://localhost:$(PORT)/echo-baggage-header")" = "(NO-HEADER)"; \
		test "$$(curl --fail --silent -H "sentry-trace: 123-456-1" "http://localhost:$(PORT)/echo-sentry-trace")" = "123-456-1"; \
		test "$$(curl --fail --silent "http://localhost:$(PORT)/echo-sentry-trace")" = "(NO-HEADER)"; \
		test "$$(curl --silent --output /dev/null --write-out "%{http_code}" "http://localhost:$(PORT)/http-client-error")" = "400"

.PHONY: run
run: build
	"$(abspath $(TEST_SERVER_EXECUTABLE))" serve --port "$(PORT)"

.PHONY: stop
stop:
	@if [ -f "$(PID_FILE)" ]; then \
		pid=$$(cat "$(PID_FILE)"); \
		if kill -0 "$$pid" 2>/dev/null; then \
			kill "$$pid"; \
			echo "Test server (PID $$pid) stopped"; \
		else \
			echo "Test server PID $$pid was not running"; \
		fi; \
		rm "$(PID_FILE)"; \
	else \
		echo "No test-server PID file found"; \
	fi
