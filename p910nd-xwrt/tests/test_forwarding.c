#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <unistd.h>

static int read_error, write_error;
static size_t write_limit;
static int accelerate_time;
static ssize_t test_read(int fd, void *buf, size_t count);
static ssize_t test_write(int fd, const void *buf, size_t count);
static int test_gettimeofday(struct timeval *tv, void *tz);

#define main p910nd_main
#define read test_read
#define write test_write
#define gettimeofday test_gettimeofday
#include P910ND_SOURCE
#undef gettimeofday
#undef write
#undef read
#undef main

static int test_gettimeofday(struct timeval *tv, void *tz)
{
	static time_t extra;
	int result = gettimeofday(tv, tz);
	if (accelerate_time) {
		tv->tv_sec += extra;
		extra += 10;
	}
	return result;
}

static ssize_t test_read(int fd, void *buf, size_t count)
{
	if (read_error) {
		errno = read_error;
		read_error = 0;
		return -1;
	}
	return read(fd, buf, count);
}

static ssize_t test_write(int fd, const void *buf, size_t count)
{
	if (write_error) {
		errno = write_error;
		write_error = 0;
		return -1;
	}
	if (write_limit && count > write_limit)
		count = write_limit;
	return write(fd, buf, count);
}

static void wrapped_buffer(void)
{
	int fds[2];
	char data[8];
	Buffer_t *b = malloc(sizeof(*b));
	assert(b && pipe(fds) == 0);
	initBuffer(b, -1, fds[1], 1);
	b->startidx = BUFFER_SIZE - 4;
	b->endidx = 4;
	b->bytes = 8;
	memcpy(b->buffer + b->startidx, "ABCD", 4);
	memcpy(b->buffer, "EFGH", 4);
	assert(writeBuffer(b) == 4);
	assert(writeBuffer(b) == 4);
	assert(b->bytes == 0 && b->startidx == 4);
	assert(read(fds[0], data, sizeof(data)) == sizeof(data));
	assert(memcmp(data, "ABCDEFGH", sizeof(data)) == 0);
	close(fds[0]);
	close(fds[1]);
	free(b);
}

static void io_errors(void)
{
	int fds[2];
	int errors[] = { EINTR, EAGAIN, EWOULDBLOCK };
	Buffer_t b;
	fd_set rfds, wfds;
	assert(pipe(fds) == 0);
	initBuffer(&b, fds[0], fds[1], 1);
	for (size_t i = 0; i < sizeof(errors) / sizeof(errors[0]); i++) {
		read_error = errors[i];
		assert(readBuffer(&b) == 0 && b.err == 0 && !b.eof_read);
		b.bytes = b.endidx = 4;
		memcpy(b.buffer, "test", 4);
		write_error = errors[i];
		assert(writeBuffer(&b) == 0 && b.err == 0 && b.bytes == 4);
	}
	read_error = EIO;
	assert(readBuffer(&b) == -1 && (b.err & READ_ERR));
	FD_ZERO(&rfds);
	FD_ZERO(&wfds);
	prepBuffer(&b, &rfds, &wfds);
	assert(!FD_ISSET(fds[0], &rfds));
	assert(FD_ISSET(fds[1], &wfds));
	assert(writeBuffer(&b) == 4 && b.bytes == 0);
	assert(writeBuffer(&b) == 0 && b.eof_sent);
	close(fds[0]);
	close(fds[1]);
}

static void partial_write(void)
{
	int net[2], printer[2], status;
	char data[8];
	assert(socketpair(AF_UNIX, SOCK_STREAM, 0, net) == 0);
	assert(pipe(printer) == 0);
	pid_t child = fork();
	assert(child >= 0);
	if (child == 0) {
		alarm(3);
		close(net[0]);
		close(printer[0]);
		bidir = 0;
		write_limit = 4;
		_exit(copy_stream(net[1], printer[1]) != 0);
	}
	close(net[1]);
	close(printer[1]);
	assert(write(net[0], "12345678", 8) == 8);
	/* Keep the input open: all bytes must drain without another network read. */
	size_t offset = 0;
	while (offset < sizeof(data)) {
		ssize_t count = read(printer[0], data + offset, sizeof(data) - offset);
		assert(count > 0);
		offset += count;
	}
	assert(memcmp(data, "12345678", sizeof(data)) == 0);
	shutdown(net[0], SHUT_WR);
	assert(waitpid(child, &status, 0) == child);
	assert(WIFEXITED(status) && WEXITSTATUS(status) == 0);
	close(net[0]);
	close(printer[0]);
}

static void default_device(void)
{
	/* The default device name must remain valid after open_printer returns. */
	device = NULL;
	int fd = open_printer('0');
	if (fd >= 0)
		close(fd);
	assert(strcmp(device, "/dev/lp0") == 0);
}

static void large_job_counters(void)
{
	int fds[2];
	Buffer_t b;
	assert(pipe(fds) == 0);
	assert(write(fds[1], "test", 4) == 4);
	initBuffer(&b, fds[0], fds[1], 1);
	b.totalin = b.totalout = INT_MAX;
	assert(readBuffer(&b) == 4);
	assert(writeBuffer(&b) == 4);
	assert(b.totalin == (uint64_t)INT_MAX + 4);
	assert(b.totalout == b.totalin);
	close(fds[0]);
	close(fds[1]);
}

static void busy_printer(void)
{
	int net[2], printer[2], status;
	char data[4096] = {0};
	size_t pending = 0;
	assert(socketpair(AF_UNIX, SOCK_STREAM, 0, net) == 0);
	assert(socketpair(AF_UNIX, SOCK_STREAM, 0, printer) == 0);
	assert(fcntl(printer[1], F_SETFL, O_NONBLOCK) == 0);
	ssize_t count;
	while ((count = write(printer[1], data, sizeof(data))) > 0)
		pending += count;
	assert(errno == EAGAIN || errno == EWOULDBLOCK);
	pid_t child = fork();
	assert(child >= 0);
	if (child == 0) {
		alarm(5);
		close(net[0]);
		close(printer[0]);
		bidir = 1;
		accelerate_time = 1;
		_exit(copy_stream(net[1], printer[1]) != 0);
	}
	close(net[1]);
	close(printer[1]);
	assert(write(net[0], "job", 3) == 3);
	/* Simulate over 30 seconds without printer write readiness. */
	usleep(600000);
	while (pending) {
		count = read(printer[0], data, pending < sizeof(data) ? pending : sizeof(data));
		assert(count > 0);
		pending -= count;
	}
	assert(read(printer[0], data, 3) == 3 && !memcmp(data, "job", 3));
	shutdown(net[0], SHUT_WR);
	assert(waitpid(child, &status, 0) == child);
	assert(WIFEXITED(status) && WEXITSTATUS(status) == 0);
	close(net[0]);
	close(printer[0]);
}

static void closed_status_channel(void)
{
	int net[2], printer[2], status;
	char data[3];
	assert(socketpair(AF_UNIX, SOCK_STREAM, 0, net) == 0);
	assert(socketpair(AF_UNIX, SOCK_STREAM, 0, printer) == 0);
	assert(fcntl(printer[1], F_SETFL, O_NONBLOCK) == 0);
	pid_t child = fork();
	assert(child >= 0);
	if (child == 0) {
		alarm(3);
		signal(SIGPIPE, SIG_IGN);
		close(net[0]);
		close(printer[0]);
		bidir = 1;
		_exit(copy_stream(net[1], printer[1]) != 0);
	}
	close(net[1]);
	close(printer[1]);
	shutdown(net[0], SHUT_RD);
	assert(write(printer[0], "status", 6) == 6);
	usleep(200000);
	assert(write(net[0], "job", 3) == 3);
	shutdown(net[0], SHUT_WR);
	assert(read(printer[0], data, 3) == 3 && !memcmp(data, "job", 3));
	assert(waitpid(child, &status, 0) == child);
	assert(WIFEXITED(status) && WEXITSTATUS(status) == 0);
	close(net[0]);
	close(printer[0]);
}

int main(int argc, char **argv)
{
	assert(argc == 2);
	alarm(10);
	if (!strcmp(argv[1], "wrapped")) wrapped_buffer();
	else if (!strcmp(argv[1], "errors")) io_errors();
	else if (!strcmp(argv[1], "partial")) partial_write();
	else if (!strcmp(argv[1], "device")) default_device();
	else if (!strcmp(argv[1], "busy")) busy_printer();
	else if (!strcmp(argv[1], "closed-status")) closed_status_channel();
	else if (!strcmp(argv[1], "large-job")) large_job_counters();
	else abort();
	return 0;
}
