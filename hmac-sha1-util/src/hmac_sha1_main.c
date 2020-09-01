/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Sat, 16 Nov 2019 04:40:01 +0800
 */
#include <stdio.h>
#include <string.h>
#include "hmac_sha1.h"

//xwrt_hmac_sha1 <key>
int main(int argc, const char **argv)
{
	const unsigned char *key = (const unsigned char *)"";
	HMAC_SHA1_CTX sha1;
#define BLOCK_SIZE 2048
	unsigned char buf[BLOCK_SIZE];

	if (argc != 2) {
		fprintf(stderr, "Usage:\n");
		fprintf(stderr, "    %s <key>\n", argv[0]);
		return 1;
	}

	key = (const unsigned char *)argv[1];

	HMAC_SHA1_Init(&sha1);
	HMAC_SHA1_UpdateKey(&sha1, key, strlen((const char *)key));
	HMAC_SHA1_EndKey(&sha1);

	HMAC_SHA1_StartMessage(&sha1);
	while(!feof(stdin)) {
		size_t bytes = fread(buf, 1, BLOCK_SIZE, stdin);
		HMAC_SHA1_UpdateMessage(&sha1, buf, bytes);
	}
	HMAC_SHA1_EndMessage(buf, &sha1);
	HMAC_SHA1_Done(&sha1);

	fwrite(buf, 1, 20, stdout);
	return 0;
}
