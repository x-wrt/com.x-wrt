/*
 * Read natflow URL logger v2 binary events and print the legacy CSV line
 * consumed by the OpenWrt urllogger scripts.
 */
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/sysinfo.h>
#include <time.h>
#include <unistd.h>

#ifndef O_CLOEXEC
#define O_CLOEXEC 0
#endif

#define URLLOGGER_QUEUE "/dev/natflow_urllogger_queue"
#define READ_BUF_LEN 65536
#define CACHE_LIMIT 256
#define POLL_TIMEOUT_MS 1000

#ifndef AF_INET
#define AF_INET 2
#endif
#ifndef AF_INET6
#define AF_INET6 10
#endif

struct natflow_urllogger_event_hdr {
	uint16_t version;
	uint16_t header_len;
	uint16_t record_len;
	uint16_t family;
	uint32_t timestamp;
	uint16_t sport;
	uint16_t dport;
	uint8_t sip[16];
	uint8_t dip[16];
	uint8_t mac[6];
	uint16_t hits;
	uint16_t host_len;
	uint8_t method;
	uint8_t source;
	uint8_t acl_idx;
	uint8_t acl_action;
} __attribute__((packed));

static volatile sig_atomic_t exiting;

static void on_signal(int signo)
{
	(void)signo;
	exiting = 1;
}

static const char *method_name(uint8_t method)
{
	switch (method) {
	case 1:
		return "GET";
	case 2:
		return "POST";
	case 3:
		return "HEAD";
	default:
		return "NONE";
	}
}

static const char *source_name(uint8_t source)
{
	switch (source) {
	case 1:
		return "HTTP";
	case 2:
		return "HTTPS";
	case 3:
		return "QUIC";
	default:
		return "UNKNOWN";
	}
}

static int set_cache_limit(int fd, unsigned int limit)
{
	char cmd[32];
	int cmd_len;
	ssize_t len;

	cmd_len = snprintf(cmd, sizeof(cmd), "cache=%u\n", limit);
	if (cmd_len < 0 || (size_t)cmd_len >= sizeof(cmd))
		return -1;

	len = write(fd, cmd, (size_t)cmd_len);
	if (len != cmd_len)
		return -1;

	return 0;
}

static int wait_queue_readable(int fd)
{
	for (;;) {
		struct pollfd pfd;
		int ret;

		if (exiting)
			return -1;

		memset(&pfd, 0, sizeof(pfd));
		pfd.fd = fd;
		pfd.events = POLLIN | POLLRDNORM;
		ret = poll(&pfd, 1, POLL_TIMEOUT_MS);
		if (ret < 0) {
			if (errno == EINTR)
				continue;
			return -1;
		}
		if (ret == 0)
			return 0;
		if (pfd.revents & (POLLNVAL | POLLERR | POLLHUP))
			return -1;
		if (pfd.revents & (POLLIN | POLLRDNORM))
			return 1;
	}
}

static int lock_alive(const char *lock_path)
{
	return lock_path == NULL || access(lock_path, F_OK) == 0;
}

static void format_ipv6_full(const uint8_t ip[16], char *buf, size_t len)
{
	snprintf(buf, len,
	         "%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x",
	         ip[0], ip[1], ip[2], ip[3], ip[4], ip[5], ip[6], ip[7],
	         ip[8], ip[9], ip[10], ip[11], ip[12], ip[13], ip[14], ip[15]);
}

static void format_addr(uint16_t family, const uint8_t ip[16], char *buf, size_t len)
{
	if (family == AF_INET) {
		if (inet_ntop(AF_INET, ip, buf, len) != NULL)
			return;
	} else if (family == AF_INET6) {
		format_ipv6_full(ip, buf, len);
		return;
	}

	snprintf(buf, len, "family-%u", family);
}

static void format_event_time(uint32_t timestamp, char *buf, size_t len)
{
	struct sysinfo info;
	time_t now = time(NULL);
	time_t event_time;
	struct tm tm;

	if (sysinfo(&info) != 0)
		info.uptime = 0;

	event_time = now - (time_t)((uint32_t)info.uptime) + (time_t)timestamp;
	if (localtime_r(&event_time, &tm) == NULL) {
		snprintf(buf, len, "%u", timestamp);
		return;
	}

	strftime(buf, len, "%Y-%m-%d %H:%M:%S", &tm);
}

static void csv_write_field(FILE *out, const uint8_t *data, size_t len)
{
	size_t i;
	int quoted = 0;

	for (i = 0; i < len; i++) {
		if (data[i] == '"' || data[i] == ',' || data[i] == '\r' || data[i] == '\n') {
			quoted = 1;
			break;
		}
	}

	if (quoted)
		fputc('"', out);
	for (i = 0; i < len; i++) {
		if (data[i] == '"')
			fputc('"', out);
		fputc(data[i], out);
	}
	if (quoted)
		fputc('"', out);
}

static void print_event(FILE *out, const struct natflow_urllogger_event_hdr *h,
                        const uint8_t *payload, size_t payload_len)
{
	char when[32];
	char sip[INET6_ADDRSTRLEN];
	char dip[INET6_ADDRSTRLEN];

	format_event_time(h->timestamp, when, sizeof(when));
	format_addr(h->family, h->sip, sip, sizeof(sip));
	format_addr(h->family, h->dip, dip, sizeof(dip));

	fprintf(out,
	        "%s,%02X:%02X:%02X:%02X:%02X:%02X,%s,%u,%s,%u,%u,%s,%s,%u,%u,",
	        when,
	        h->mac[0], h->mac[1], h->mac[2], h->mac[3], h->mac[4], h->mac[5],
	        sip, h->sport, dip, h->dport, h->hits,
	        method_name(h->method), source_name(h->source), h->acl_idx, h->acl_action);
	csv_write_field(out, payload, payload_len);
	fputc('\n', out);
	fflush(out);
}

static int process_buffer(FILE *out, uint8_t *buf, size_t *pending)
{
	size_t off = 0;
	size_t total = *pending;

	while (total - off >= sizeof(struct natflow_urllogger_event_hdr)) {
		struct natflow_urllogger_event_hdr h;
		size_t payload_len;

		memcpy(&h, buf + off, sizeof(h));
		if (h.version != 2 ||
		    h.header_len < sizeof(h) ||
		    h.record_len < h.header_len ||
		    h.record_len > total - off) {
			break;
		}

		payload_len = h.record_len - h.header_len;
		print_event(out, &h, buf + off + h.header_len, payload_len);
		off += h.record_len;
	}

	if (off > 0) {
		memmove(buf, buf + off, total - off);
		*pending = total - off;
	}

	if (*pending == READ_BUF_LEN)
		*pending = 0;

	return 0;
}

static int read_loop(const char *lock_path)
{
	uint8_t buf[READ_BUF_LEN];
	size_t pending = 0;
	int fd;

	fd = open(URLLOGGER_QUEUE, O_RDWR | O_CLOEXEC);
	if (fd < 0)
		return 1;
	if (set_cache_limit(fd, CACHE_LIMIT) != 0) {
		close(fd);
		return 1;
	}

	while (!exiting && lock_alive(lock_path)) {
		ssize_t len;
		int ready = wait_queue_readable(fd);

		if (ready < 0)
			break;
		if (ready == 0)
			continue;

		for (;;) {
			if (pending >= sizeof(buf))
				pending = 0;
			len = read(fd, buf + pending, sizeof(buf) - pending);
			if (len < 0) {
				if (errno == EINTR)
					continue;
				exiting = 1;
				break;
			}
			if (len == 0)
				break;
			pending += (size_t)len;
			process_buffer(stdout, buf, &pending);
			if ((size_t)len < sizeof(buf) - pending)
				break;
		}
	}

	set_cache_limit(fd, 0);
	close(fd);
	return 0;
}

static int clear_queue(void)
{
	int fd = open(URLLOGGER_QUEUE, O_RDWR | O_CLOEXEC);
	int ret;

	if (fd < 0)
		return 1;
	ret = set_cache_limit(fd, 0);
	close(fd);
	return ret == 0 ? 0 : 1;
}

static void usage(const char *prog)
{
	fprintf(stderr, "usage: %s [--clear] [--lock PATH]\n", prog);
}

int main(int argc, char **argv)
{
	const char *lock_path = NULL;
	int clear = 0;
	int i;

	for (i = 1; i < argc; i++) {
		if (strcmp(argv[i], "--clear") == 0) {
			clear = 1;
		} else if (strcmp(argv[i], "--lock") == 0 && i + 1 < argc) {
			lock_path = argv[++i];
		} else {
			usage(argv[0]);
			return 1;
		}
	}

	if (clear)
		return clear_queue();

	signal(SIGINT, on_signal);
	signal(SIGTERM, on_signal);
	return read_loop(lock_path);
}
