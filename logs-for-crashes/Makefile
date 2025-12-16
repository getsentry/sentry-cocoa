CC = clang
CFLAGS = -Wall -Wextra -std=c11 -g
TARGET = buffer_test
SIGNAL_TEST = signal_test
BUFFER_SIGNAL_TEST = buffer_signal_test
SOURCES = sentry_batch_buffer.c main.c
SIGNAL_SOURCES = sentry_signal_handler.c test_signal_handler.c
BUFFER_SIGNAL_SOURCES = sentry_batch_buffer.c sentry_signal_handler.c test_buffer_with_signals.c
BUFFER_SIGNAL_OBJECTS = $(BUFFER_SIGNAL_SOURCES:.c=.o)
SIGNAL_OBJECTS = $(SIGNAL_SOURCES:.c=.o)
OBJECTS = $(SOURCES:.c=.o)

.PHONY: all clean run test-signal test-buffer-signal

all: $(TARGET) $(SIGNAL_TEST) $(BUFFER_SIGNAL_TEST)

$(TARGET): $(OBJECTS)
	$(CC) $(CFLAGS) -o $(TARGET) $(OBJECTS)

$(SIGNAL_TEST): $(SIGNAL_OBJECTS)
	$(CC) $(CFLAGS) -o $(SIGNAL_TEST) $(SIGNAL_OBJECTS)

$(BUFFER_SIGNAL_TEST): $(BUFFER_SIGNAL_OBJECTS)
	$(CC) $(CFLAGS) -o $(BUFFER_SIGNAL_TEST) $(BUFFER_SIGNAL_OBJECTS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

run: $(TARGET)
	./$(TARGET)

test-signal: $(SIGNAL_TEST)
	./$(SIGNAL_TEST)

test-buffer-signal: $(BUFFER_SIGNAL_TEST)
	./$(BUFFER_SIGNAL_TEST)

clean:
	rm -f $(OBJECTS) $(SIGNAL_OBJECTS) $(BUFFER_SIGNAL_OBJECTS) $(TARGET) $(SIGNAL_TEST) $(BUFFER_SIGNAL_TEST) buffer_output.txt
