/*
 * epoll-fork.c - Linux epoll descriptors across fork(2) under the Linuxulator
 *
 * Part of Immutablue (freebsd-be). AGPL-3.0-or-later.
 *
 * On Linux an epoll descriptor is inherited by a forked child like any other
 * descriptor. FreeBSD's Linuxulator implements epoll with a kqueue, and a
 * kqueue is not inherited: in the child the descriptor number is simply
 * empty, so close(2) on it fails with EBADF. Ruby's timer thread keeps an
 * epoll descriptor and closes it in every forked child before making a new
 * one; on EBADF it aborts ("[ASYNC BUG] close event_fd ... EBADF") with a
 * crash report thousands of lines long. Homebrew forks constantly.
 *
 * This library, loaded into every process of the Linux userland through
 * /etc/ld.so.preload, remembers which descriptors epoll_create(2) and
 * epoll_create1(2) returned. When close(2) on one of them fails with EBADF it
 * reports success instead -- what Linux would have answered, since there the
 * child would have inherited the descriptor and closed it. Every other
 * close(2) is passed through untouched.
 *
 * Built by immutablue-linux inside the userland:
 *   gcc -std=gnu89 -O2 -Wall -Wextra -shared -fPIC \
 *       -o /usr/local/lib64/immutablue-epoll-fork.so epoll-fork.c -ldl
 */

#define _GNU_SOURCE

#include <dlfcn.h>
#include <errno.h>
#include <sys/epoll.h>
#include <unistd.h>

/* descriptors tracked: anything above this is passed through untouched */
#define EPOLL_FORK_MAX_FD (65536)

/* one bit per descriptor number: set while it is an epoll descriptor */
static unsigned char epoll_fds[EPOLL_FORK_MAX_FD / 8];

typedef int (*CloseFunc)(int);
typedef int (*EpollCreateFunc)(int);


/*
 * epoll_fork_mark:
 * @fd: a descriptor
 * @on: 1 to record @fd as an epoll descriptor, 0 to forget it
 *
 * Records or forgets @fd in the epoll descriptor set.
 */
static void
epoll_fork_mark(
	int     fd,
	int     on
){
	if (fd < 0 || fd >= EPOLL_FORK_MAX_FD)
		return;
	if (on)
		epoll_fds[fd / 8] |= (unsigned char)(1 << (fd % 8));
	else
		epoll_fds[fd / 8] &= (unsigned char)~(1 << (fd % 8));
}


/*
 * epoll_fork_is_marked:
 * @fd: a descriptor
 *
 * Returns: 1 when @fd was returned by epoll_create and not closed since
 */
static int
epoll_fork_is_marked(
	int     fd
){
	if (fd < 0 || fd >= EPOLL_FORK_MAX_FD)
		return 0;
	return (epoll_fds[fd / 8] >> (fd % 8)) & 1;
}


/*
 * epoll_create1:
 * @flags: EPOLL_CLOEXEC or 0
 *
 * The real epoll_create1, recording the descriptor it returns.
 *
 * Returns: the new epoll descriptor, or -1 with errno set
 */
int
epoll_create1(
	int     flags
){
	static EpollCreateFunc real_epoll_create1 = NULL;
	int fd;

	if (real_epoll_create1 == NULL)
		real_epoll_create1 = (EpollCreateFunc)dlsym(RTLD_NEXT, "epoll_create1");
	fd = real_epoll_create1(flags);
	if (fd >= 0)
		epoll_fork_mark(fd, 1);
	return fd;
}


/*
 * epoll_create:
 * @size: ignored by Linux since 2.6.8, but must be positive
 *
 * The real epoll_create, recording the descriptor it returns.
 *
 * Returns: the new epoll descriptor, or -1 with errno set
 */
int
epoll_create(
	int     size
){
	static EpollCreateFunc real_epoll_create = NULL;
	int fd;

	if (real_epoll_create == NULL)
		real_epoll_create = (EpollCreateFunc)dlsym(RTLD_NEXT, "epoll_create");
	fd = real_epoll_create(size);
	if (fd >= 0)
		epoll_fork_mark(fd, 1);
	return fd;
}


/*
 * close:
 * @fd: the descriptor to close
 *
 * The real close. For a recorded epoll descriptor, EBADF -- the descriptor
 * was not inherited across fork -- is reported as success, as Linux would.
 *
 * Returns: 0 on success, or -1 with errno set
 */
int
close(
	int     fd
){
	static CloseFunc real_close = NULL;
	int saved_errno;
	int rc;

	if (real_close == NULL)
		real_close = (CloseFunc)dlsym(RTLD_NEXT, "close");

	saved_errno = errno;
	rc = real_close(fd);
	if (!epoll_fork_is_marked(fd))
		return rc;

	/* either way this number no longer names an epoll descriptor */
	epoll_fork_mark(fd, 0);
	if (rc == -1 && errno == EBADF)
	{
		errno = saved_errno;
		return 0;
	}
	return rc;
}
