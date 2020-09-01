/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Sat, 16 Nov 2019 04:40:01 +0800
 */
#include <stdio.h>
#include <string.h>
#include <cyassl/ctaocrypt/hmac.h>

//xwrt_hmac_sha1 <key>
int main(int argc, const char **argv)
{
	const unsigned char *key = (const unsigned char *)"";
	Hmac sha1;
#define BLOCK_SIZE 2048
	unsigned char buf[BLOCK_SIZE];

	if (argc != 2) {
		fprintf(stderr, "Usage:\n");
		fprintf(stderr, "    %s <key>\n", argv[0]);
		return 1;
	}

	key = (const unsigned char *)argv[1];

	HmacSetKey(&sha1, SHA, key, strlen((const char *)key));
	while(!feof(stdin)) {
		size_t bytes = fread(buf, 1, BLOCK_SIZE, stdin);
		HmacUpdate(&sha1, buf, bytes);
	}
	HmacFinal(&sha1, buf);

	fwrite(buf, 1, 20, stdout);
	return 0;
}
