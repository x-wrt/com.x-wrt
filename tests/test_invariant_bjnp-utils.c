#include <check.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include "bjnp-utils.h"

START_TEST(test_buffer_reads_never_exceed_declared_length)
{
    // Invariant: Buffer reads never exceed the declared length
    const char *payloads[] = {
        // Exact exploit case: IPv6 address near max length with scope_id
        "2001:0db8:85a3:0000:0000:8a2e:0370:7334",
        // Boundary case: Maximum length IPv6 address (39 chars without brackets)
        "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
        // Valid input: Short IPv6 address
        "::1",
        // Adversarial: Excessively long string (10x normal)
        "2001:0db8:85a3:0000:0000:8a2e:0370:7334:extra:padding:to:exceed:buffer:by:10x:length"
    };
    int num_payloads = sizeof(payloads) / sizeof(payloads[0]);

    for (int i = 0; i < num_payloads; i++) {
        struct sockaddr_in6 addr;
        char addr_string[256];
        
        memset(&addr, 0, sizeof(addr));
        addr.sin6_family = AF_INET6;
        addr.sin6_scope_id = 25; // Force scope_id inclusion
        
        // Convert string to IPv6 address
        if (inet_pton(AF_INET6, payloads[i], &addr.sin6_addr) == 1) {
            // Call the actual production function
            get_address_info((struct sockaddr *)&addr, addr_string, sizeof(addr_string));
            
            // Verify the output doesn't exceed buffer bounds
            ck_assert_msg(strlen(addr_string) < sizeof(addr_string),
                         "Buffer overflow detected for payload: %s", payloads[i]);
            
            // Verify null termination
            ck_assert_msg(addr_string[sizeof(addr_string)-1] == '\0',
                         "Missing null terminator for payload: %s", payloads[i]);
        }
    }
}
END_TEST

Suite *security_suite(void)
{
    Suite *s;
    TCase *tc_core;

    s = suite_create("Security");
    tc_core = tcase_create("Core");

    tcase_add_test(tc_core, test_buffer_reads_never_exceed_declared_length);
    suite_add_tcase(s, tc_core);

    return s;
}

int main(void)
{
    int number_failed;
    Suite *s;
    SRunner *sr;

    s = security_suite();
    sr = srunner_create(s);

    srunner_run_all(sr, CK_NORMAL);
    number_failed = srunner_ntests_failed(sr);
    srunner_free(sr);

    return (number_failed == 0) ? EXIT_SUCCESS : EXIT_FAILURE;
}