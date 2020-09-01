CC = gcc
CFLAGS = -Wall -Werror
LDFLAGS =

BINS = hmac-sha1-util
OBJS = sha1.o hmac_sha1.o hmac_sha1_main.o

all: $(BINS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

hmac-sha1-util: $(OBJS)
	$(CC) -o $@ $(OBJS) $(LDFLAGS)

clean:
	rm -f *.o $(BINS)
