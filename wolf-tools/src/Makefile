CC = gcc
CFLAGS = -Wall -Werror
LDFLAGS = -lwolfssl

BINS = wolf-hmac-sha1

all: $(BINS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

wolf-hmac-sha1: wolf_hmac_sha1.o
	$(CC) -o $@ $< $(LDFLAGS)

clean:
	rm -f *.o $(BINS)
