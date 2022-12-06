DAYS := $(wildcard */*.s)
TARGETS := $(patsubst %.s,%,$(DAYS))

CC := gcc
CFLAGS := -Wall -Wextra -Wl,-z -Wl,noexecstack -nostdlib -no-pie

all: $(TARGETS)

clean:
	rm -f $(TARGETS)

%: %.s stdlib.s
	$(CC) $(CFLAGS) -o $@ $^
