// Send a command to yabai-helper: wmctl <command> [args...], e.g. wmctl ws focus next. Binds use it instead of a bash
// script that runs yabai and jq several times (~15 ms): this takes ~1 ms, and the helper answers over yabai's socket.
// One datagram per command on ~/.cache/yabai-helper.sock, args NUL-separated; the helper runs them in order, so quick
// presses queue rather than overlap or get dropped. Exits 1 if the helper isn't running. Built by setup.sh.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

int main(int argc, char **argv) {
	if (argc < 2) { fprintf(stderr, "usage: wmctl <command> [args...]\n"); return 2; }
	char msg[1024];
	size_t n = 0;
	for (int i = 1; i < argc; i++) {
		size_t len = strlen(argv[i]) + 1;
		if (n + len > sizeof msg) return 2;
		memcpy(msg + n, argv[i], len);
		n += len;
	}
	struct sockaddr_un addr = {.sun_family = AF_UNIX};
	snprintf(addr.sun_path, sizeof addr.sun_path, "%s/.cache/yabai-helper.sock", getenv("HOME"));
	int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
	if (fd < 0 || sendto(fd, msg, n, 0, (struct sockaddr *)&addr, sizeof addr) < 0) {
		perror("wmctl: yabai-helper");
		return 1;
	}
	return 0;
}
