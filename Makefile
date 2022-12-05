DAYS := $(wildcard */*.s)
TARGETS := $(patsubst %.s,%,$(DAYS))

CC := gcc
CFLAGS := -Wall -Wextra -Wl,-z -Wl,noexecstack

all: $(TARGETS)

clean:
	rm -f $(TARGETS)

%: %.s
	$(CC) $(CFLAGS) -o $@ $^
