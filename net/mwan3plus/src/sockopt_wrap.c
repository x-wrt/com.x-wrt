// SPDX-License-Identifier: GPL-2.0
/*
 * Robust Dual-Stack LD_PRELOAD Socket Wrapper (Production Grade)
 *
 * Fixes & Hardening applied:
 * 1. Comprehensive dlsym validation for all core functions.
 * 2. Improved accept() guards to validate sockfd state.
 * 3. Added FD bounds logging for diagnostics.
 * 4. Memory barriers in socket() initialization to prevent compiler reordering.
 * 5. errno preservation to prevent application logic pollution.
 * 6. Lazy initialization (ENSURE_INIT) to survive C++ early static initializer calls.
 * 7. sendmmsg() interception for high-performance QUIC/DNS/Nginx servers.
 * 8. volatile is_socket to prevent aggressive compiler optimizations.
 * 9. Optional function pointers (dup3/accept4/sendmmsg) allow graceful fallback.
 * 10. Memset fd_info on close() for complete cleanup (corrected ordering).
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <errno.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sched.h>

#ifndef __GLIBC__
// 非 glibc 环境 (如 musl)
#define SENDMMSG_FLAGS_TYPE unsigned int
#else
// glibc 环境
#define SENDMMSG_FLAGS_TYPE int
#endif

#ifndef MAX_FDS
// 现代 Linux 默认的合理上限，占用约 256KB 内存，非常安全
#define MAX_FDS 65536
#endif

// 使用 __sync_bool_compare_and_swap 等原子操作，无需加锁
struct socket_state {
	volatile int bound;     // 0=未绑定, 1=已绑定 (使用 atomic 操作)
	volatile int is_socket; // FIX #8: 0=普通文件, 1=被我们追踪的socket (防优化)
	int domain;             // AF_INET 或 AF_INET6
};

enum {
	BOUND_NO = 0,
	BOUND_YES = 1,
	BOUND_IN_PROGRESS = 2,
};

// 全局状态数组 (存放在 BSS 段，自动初始化为 0)
static struct socket_state fd_info[MAX_FDS];

// 全局配置 (在初始化中一次性设置，只读，线程安全)
static struct sockaddr_in  source4 = {0};
static int has_source4 = 0;
static int source4_invalid = 0;
#ifdef CONFIG_IPV6
static struct sockaddr_in6 source6 = {0};
static int has_source6 = 0;
static int source6_invalid = 0;
#endif

static char dev_name[IFNAMSIZ] = {0};
static int has_dev = 0;
static int fwmark_val = 0;
static int has_fwmark = 0;
static int reject_ipv4 = 0;
static int reject_ipv6 = 0;

// 原始函数指针
static int (*orig_socket)(int, int, int);
static int (*orig_bind)(int, const struct sockaddr*, socklen_t);
static int (*orig_setsockopt)(int, int, int, const void*, socklen_t);
static int (*orig_close)(int);
static int (*orig_getsockname)(int, struct sockaddr*, socklen_t*);
static int (*orig_connect)(int, const struct sockaddr*, socklen_t);
static ssize_t (*orig_send)(int, const void*, size_t, int);
static ssize_t (*orig_sendto)(int, const void*, size_t, int, const struct sockaddr*, socklen_t);
static ssize_t (*orig_sendmsg)(int, const struct msghdr*, int);
static int (*orig_sendmmsg)(int, struct mmsghdr*, unsigned int, SENDMMSG_FLAGS_TYPE); // FIX #7: 可选
static int (*orig_dup)(int);
static int (*orig_dup2)(int, int);
static int (*orig_dup3)(int, int, int);        // FIX #9: 可选 (glibc 2.9+)
static int (*orig_accept)(int, struct sockaddr*, socklen_t*);
static int (*orig_accept4)(int, struct sockaddr*, socklen_t*, int); // FIX #9: 可选 (glibc 2.10+)

// 原子初始化状态: 0=未初始化, 1=初始化中, 2=完成
static volatile int init_state = 0;

// ==========================================
// 初始化阶段
// ==========================================
static void init_lib(void) {
	// 使用原子操作确保多线程下只初始化一次
	if (!__sync_bool_compare_and_swap(&init_state, 0, 1)) {
		while (__builtin_expect(init_state != 2, 0)) {
			sched_yield();
		}
		return;
	}

	// FIX #1: 加载所有核心函数指针
	orig_socket = dlsym(RTLD_NEXT, "socket");
	orig_bind = dlsym(RTLD_NEXT, "bind");
	orig_setsockopt = dlsym(RTLD_NEXT, "setsockopt");
	orig_close = dlsym(RTLD_NEXT, "close");
	orig_getsockname = dlsym(RTLD_NEXT, "getsockname");
	orig_connect = dlsym(RTLD_NEXT, "connect");
	orig_send = dlsym(RTLD_NEXT, "send");
	orig_sendto = dlsym(RTLD_NEXT, "sendto");
	orig_sendmsg = dlsym(RTLD_NEXT, "sendmsg");
	orig_dup = dlsym(RTLD_NEXT, "dup");
	orig_dup2 = dlsym(RTLD_NEXT, "dup2");
	orig_accept = dlsym(RTLD_NEXT, "accept");

	// FIX #9: 可选函数 (允许为 NULL)
	orig_dup3 = dlsym(RTLD_NEXT, "dup3");
	orig_accept4 = dlsym(RTLD_NEXT, "accept4");
	orig_sendmmsg = dlsym(RTLD_NEXT, "sendmmsg");

	// FIX #1: 验证所有核心函数指针
	if (!orig_socket || !orig_bind || !orig_close || !orig_connect ||
	        !orig_send || !orig_sendto || !orig_sendmsg || !orig_dup ||
	        !orig_dup2 || !orig_accept || !orig_setsockopt || !orig_getsockname) {
		fprintf(stderr, "sockwrap: Fatal error, dlsym failed for core functions.\n");
		exit(EXIT_FAILURE);
	}

	// 解析环境变量 (一次性解析，消除运行时的 getenv 开销)
	const char *env_dev = getenv("DEVICE");
	if (env_dev && strlen(env_dev) > 0) {
		size_t dev_len = strnlen(env_dev, IFNAMSIZ);
		if (dev_len >= IFNAMSIZ) {
			fprintf(stderr, "sockwrap: interface name too long\n");
			exit(EXIT_FAILURE);
		}
		memcpy(dev_name, env_dev, dev_len + 1);
		has_dev = 1;
	}

	const char *env_mark = getenv("FWMARK");
	if (env_mark) {
		fwmark_val = (int)strtol(env_mark, NULL, 0);
		has_fwmark = fwmark_val > 0;
	}

	const char *env_ip4 = getenv("SRCIP4") ? getenv("SRCIP4") : getenv("SRCIP");
	if (env_ip4 && strlen(env_ip4) > 0) {
		if (inet_pton(AF_INET, env_ip4, &source4.sin_addr) > 0) {
			source4.sin_family = AF_INET;
			has_source4 = 1;
		} else {
			source4_invalid = 1;
		}
	}

#ifdef CONFIG_IPV6
	const char *env_ip6 = getenv("SRCIP6") ? getenv("SRCIP6") : getenv("SRCIP");
	if (env_ip6 && strlen(env_ip6) > 0) {
		if (inet_pton(AF_INET6, env_ip6, &source6.sin6_addr) > 0) {
			source6.sin6_family = AF_INET6;
			has_source6 = 1;
		} else {
			source6_invalid = 1;
		}
	}
#endif

	const char *env_family = getenv("FAMILY");
	if (env_family) {
		if (strcasecmp(env_family, "ipv4") == 0) reject_ipv6 = 1;
		if (strcasecmp(env_family, "ipv6") == 0) reject_ipv4 = 1;
	}

	__sync_synchronize();
	init_state = 2;
}

// 标准 constructor 初始化入口
__attribute__((constructor)) static void constructor_init(void) {
	init_lib();
}

// FIX #6: 懒加载宏。__builtin_expect 告诉编译器 is_initialized 通常为 1，
// 这样在汇编层面几乎没有性能损耗（零开销分支预测）。
#define ENSURE_INIT() do { \
    if (__builtin_expect(init_state != 2, 0)) init_lib(); \
} while(0)

// ==========================================
// 核心逻辑
// ==========================================
static int get_source_addr(int domain, const struct sockaddr **addr, socklen_t *len) {
	if (domain == AF_INET && source4_invalid) {
		errno = EINVAL;
		return -1;
	}
	if (domain == AF_INET && has_source4) {
		*addr = (const struct sockaddr *)&source4;
		*len = sizeof(source4);
		return 1;
	}
#ifdef CONFIG_IPV6
	if (domain == AF_INET6 && source6_invalid) {
		errno = EINVAL;
		return -1;
	}
	if (domain == AF_INET6 && has_source6) {
		*addr = (const struct sockaddr *)&source6;
		*len = sizeof(source6);
		return 1;
	}
#endif
	return 0;
}

static int bind_source_addr(int sockfd, int domain) {
	const struct sockaddr *addr = NULL;
	socklen_t len = 0;

	int source_status = get_source_addr(domain, &addr, &len);
	if (source_status < 0) {
		return -1;
	}
	if (!source_status) {
		return 0;
	}

	return orig_bind(sockfd, addr, len);
}

static int sockaddr_needs_source_bind(const struct sockaddr *addr) {
	if (addr->sa_family == AF_INET) {
		const struct sockaddr_in *addr4 = (const struct sockaddr_in *)addr;
		return addr4->sin_port == 0 && addr4->sin_addr.s_addr == htonl(INADDR_ANY);
	}
#ifdef CONFIG_IPV6
	if (addr->sa_family == AF_INET6) {
		const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6 *)addr;
		return addr6->sin6_port == 0 && IN6_IS_ADDR_UNSPECIFIED(&addr6->sin6_addr);
	}
#endif
	return 0;
}

static int dobind_untracked(int sockfd) {
	struct sockaddr_storage local_addr;
	socklen_t len = sizeof(local_addr);

	if (!has_source4
#ifdef CONFIG_IPV6
	    && !has_source6
#endif
	    ) {
		return 0;
	}

	if (orig_getsockname(sockfd, (struct sockaddr *)&local_addr, &len) < 0) {
		return 0;
	}

	if (!sockaddr_needs_source_bind((struct sockaddr *)&local_addr)) {
		return 0;
	}

	return bind_source_addr(sockfd, local_addr.ss_family);
}

static int dobind(int sockfd) {
	if (sockfd < 0) return 0;

	if (sockfd >= MAX_FDS || !fd_info[sockfd].is_socket) {
		return dobind_untracked(sockfd);
	}

	for (;;) {
		int state = fd_info[sockfd].bound;

		if (state == BOUND_YES) return 0;

		if (state == BOUND_IN_PROGRESS) {
			sched_yield();
			continue;
		}

		if (__sync_bool_compare_and_swap(&fd_info[sockfd].bound, BOUND_NO, BOUND_IN_PROGRESS)) {
			int ret = bind_source_addr(sockfd, fd_info[sockfd].domain);
			fd_info[sockfd].bound = ret == 0 ? BOUND_YES : BOUND_NO;
			__sync_synchronize();
			return ret;
		}
	}
}

static int apply_socket_options(int fd) {
	int saved_errno = errno;

	if (has_dev && orig_setsockopt(fd, SOL_SOCKET, SO_BINDTODEVICE, dev_name, strlen(dev_name) + 1) < 0) {
		return -1;
	}

	if (has_fwmark && orig_setsockopt(fd, SOL_SOCKET, SO_MARK, &fwmark_val, sizeof(fwmark_val)) < 0) {
		return -1;
	}

	errno = saved_errno;
	return 0;
}

// ==========================================
// Hook 拦截区
// ==========================================

int socket(int domain, int type, int protocol) {
	ENSURE_INIT();

	if ((domain == AF_INET && reject_ipv4) || (domain == AF_INET6 && reject_ipv6)) {
		errno = EAFNOSUPPORT;
		return -1;
	}
	if ((domain == AF_INET && source4_invalid)
#ifdef CONFIG_IPV6
	    || (domain == AF_INET6 && source6_invalid)
#endif
	    ) {
		errno = EINVAL;
		return -1;
	}

	int fd = orig_socket(domain, type, protocol);
	if (fd >= 0 && (domain == AF_INET || domain == AF_INET6)) {
		if (apply_socket_options(fd) < 0) {
			int saved_errno = errno;
			orig_close(fd);
			errno = saved_errno;
			return -1;
		}

		if (fd < MAX_FDS) {
			// FIX #4: 初始化顺序与内存屏障确保其他线程看到一致的状态
			fd_info[fd].domain = domain;
			fd_info[fd].bound = BOUND_NO;
			__sync_synchronize();  // 完整内存屏障
			fd_info[fd].is_socket = 1;
		}
	}
	return fd;
}

int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
	ENSURE_INIT();

	if (addr) {
		struct sockaddr_storage tmp_addr;
		const struct sockaddr *bind_addr = addr;

		if ((addr->sa_family == AF_INET && has_source4)
#ifdef CONFIG_IPV6
		    || (addr->sa_family == AF_INET6 && has_source6)
#endif
		    ) {
			if (addrlen > sizeof(tmp_addr)) {
				errno = EINVAL;
				return -1;
			}

			memcpy(&tmp_addr, addr, addrlen);

			if (addr->sa_family == AF_INET) {
				((struct sockaddr_in*)&tmp_addr)->sin_addr = source4.sin_addr;
			}
#ifdef CONFIG_IPV6
			else if (addr->sa_family == AF_INET6) {
				((struct sockaddr_in6*)&tmp_addr)->sin6_addr = source6.sin6_addr;
			}
#endif
			bind_addr = (struct sockaddr *)&tmp_addr;
		}

		int ret = orig_bind(sockfd, bind_addr, addrlen);
		if (ret == 0 && sockfd >= 0 && sockfd < MAX_FDS && fd_info[sockfd].is_socket) {
			fd_info[sockfd].bound = BOUND_YES;
		}
		return ret;
	}
	return orig_bind(sockfd, addr, addrlen);
}

int setsockopt(int sockfd, int level, int optname, const void *optval, socklen_t optlen) {
	ENSURE_INIT();

	// 屏蔽目标程序擅自修改网卡或防火墙标记
	if (level == SOL_SOCKET && (optname == SO_MARK || optname == SO_BINDTODEVICE)) {
		return 0; // 假装成功
	}
	return orig_setsockopt(sockfd, level, optname, optval, optlen);
}

// ------------------------------------------
// 数据发送与连接 Hook (触发 dobind)
// ------------------------------------------
int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
	ENSURE_INIT();
	if (dobind(sockfd) < 0) return -1;
	return orig_connect(sockfd, addr, addrlen);
}

ssize_t send(int sockfd, const void *buf, size_t len, int flags) {
	ENSURE_INIT();
	if (dobind(sockfd) < 0) return -1;
	return orig_send(sockfd, buf, len, flags);
}

ssize_t sendto(int sockfd, const void *buf, size_t len, int flags, const struct sockaddr *dest_addr, socklen_t addrlen) {
	ENSURE_INIT();
	if (dobind(sockfd) < 0) return -1;
	return orig_sendto(sockfd, buf, len, flags, dest_addr, addrlen);
}

ssize_t sendmsg(int sockfd, const struct msghdr *msg, int flags) {
	ENSURE_INIT();
	if (dobind(sockfd) < 0) return -1;
	return orig_sendmsg(sockfd, msg, flags);
}

// FIX #7: 支持高级批量发送系统调用 (如 QUIC/Nginx 使用)
int sendmmsg(int sockfd, struct mmsghdr *msgvec, unsigned int vlen, SENDMMSG_FLAGS_TYPE flags) {
	ENSURE_INIT();

	// FIX #9: 二次检查防止 SIGSEGV
	if (__builtin_expect(!orig_sendmmsg, 0)) {
		errno = ENOSYS;
		return -1;
	}

	if (dobind(sockfd) < 0) return -1;
	return orig_sendmmsg(sockfd, msgvec, vlen, flags);
}

// ------------------------------------------
// 状态同步 Hook (极其重要，防止 FD 状态断层)
// ------------------------------------------
static void sync_fd_state(int oldfd, int newfd) {
	if (oldfd < 0 || oldfd >= MAX_FDS || newfd < 0 || newfd >= MAX_FDS) return;

	fd_info[newfd].domain = fd_info[oldfd].domain;
	fd_info[newfd].bound = fd_info[oldfd].bound == BOUND_IN_PROGRESS ? BOUND_NO : fd_info[oldfd].bound;
	__sync_synchronize();
	fd_info[newfd].is_socket = fd_info[oldfd].is_socket;
}

int dup(int oldfd) {
	ENSURE_INIT();
	int newfd = orig_dup(oldfd);
	if (newfd >= 0) sync_fd_state(oldfd, newfd);
	return newfd;
}

int dup2(int oldfd, int newfd) {
	ENSURE_INIT();
	int ret = orig_dup2(oldfd, newfd);
	if (ret >= 0) sync_fd_state(oldfd, newfd);
	return ret;
}

int dup3(int oldfd, int newfd, int flags) {
	ENSURE_INIT();

	// FIX #9: dup3 是可选的 (glibc 2.9+)
	if (!orig_dup3) {
		errno = ENOSYS;
		return -1;
	}

	int ret = orig_dup3(oldfd, newfd, flags);
	if (ret >= 0) sync_fd_state(oldfd, newfd);
	return ret;
}

// FIX #2: 改进 handle_accept 守卫条件
static void handle_accept(int sockfd, int newfd) {
	if (sockfd < 0 || sockfd >= MAX_FDS || !fd_info[sockfd].is_socket) {
		// FIX #3: 添加日志用于诊断
		if (sockfd >= MAX_FDS) {
			fprintf(stderr, "sockwrap: Warning - accept sockfd %d exceeds MAX_FDS (%d)\n",
			        sockfd, MAX_FDS);
		}
		return;
	}

	if (newfd < 0 || newfd >= MAX_FDS) {
		// FIX #3: 添加日志用于诊断
		if (newfd >= MAX_FDS) {
			fprintf(stderr, "sockwrap: Warning - accept newfd %d exceeds MAX_FDS (%d)\n",
			        newfd, MAX_FDS);
		}
		return;
	}

	// Accept 产生的是已经连接的 Socket，标记为 bound=1 防止误操作
	fd_info[newfd].domain = fd_info[sockfd].domain;
	fd_info[newfd].bound = BOUND_YES;
	__sync_synchronize();
	fd_info[newfd].is_socket = 1;
}

int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen) {
	ENSURE_INIT();
	int newfd = orig_accept(sockfd, addr, addrlen);
	if (newfd >= 0) handle_accept(sockfd, newfd);
	return newfd;
}

int accept4(int sockfd, struct sockaddr *addr, socklen_t *addrlen, int flags) {
	ENSURE_INIT();

	// FIX #9: accept4 是可选的 (glibc 2.10+)
	if (!orig_accept4) {
		errno = ENOSYS;
		return -1;
	}

	int newfd = orig_accept4(sockfd, addr, addrlen, flags);
	if (newfd >= 0) handle_accept(sockfd, newfd);
	return newfd;
}

// ------------------------------------------
// 资源释放
// ------------------------------------------
int close(int sockfd) {
	ENSURE_INIT();

	if (sockfd >= 0 && sockfd < MAX_FDS) {
		// FIX #10 (正确版): 原子清零防止 FD 复用时的状态泄露
		// 关键：先标记为非 socket，防止其他线程继续操作
		fd_info[sockfd].is_socket = 0;
		__sync_synchronize();  // 全局屏障，确保所有线程都看到 is_socket = 0

		// 然后清理其他状态 (此时不会有新操作进入)
		fd_info[sockfd].bound = BOUND_NO;
		fd_info[sockfd].domain = 0;
	}
	return orig_close(sockfd);
}
