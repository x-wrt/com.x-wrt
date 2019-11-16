CC = gcc
CFLAGS = -Wall -Werror
LDFLAGS = -lmbedcrypto

BINS = mbed-hmac-sha1

all: $(BINS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

mbed-hmac-sha1: mbed_hmac_sha1.o
	$(CC) -o $@ $< $(LDFLAGS)

clean:
	rm -f *.o $(BINS)
