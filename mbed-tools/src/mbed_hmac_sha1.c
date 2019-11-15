/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Sat, 16 Nov 2019 04:40:01 +0800
 */
#include <stdio.h>
#include <string.h>
#include <mbedtls/md.h>
#include <mbedtls/sha1.h>

//xwrt_hmac_sha1 <key>
int main(int argc, const char **argv)
{
	const char *key = "";
	mbedtls_md_context_t ctx;
#define BLOCK_SIZE 2048
	unsigned char buf[BLOCK_SIZE];

	if (argc != 2) {
		fprintf(stderr, "Usage:\n");
		fprintf(stderr, "    %s <key>\n", argv[0]);
		return 1;
	}

	key = argv[1];
	mbedtls_md_init(&ctx);
	mbedtls_md_setup(&ctx, mbedtls_md_info_from_type(MBEDTLS_MD_SHA1), 1);
	mbedtls_md_hmac_starts(&ctx, (const unsigned char *)key, strlen(key));

	while(!feof(stdin)) {
		size_t bytes = fread(buf, 1, BLOCK_SIZE, stdin);
		mbedtls_md_hmac_update(&ctx, (const unsigned char *)buf, bytes);
	}

	mbedtls_md_hmac_finish(&ctx, buf);

	fwrite(buf, 1, 20, stdout);
	return 0;
}
