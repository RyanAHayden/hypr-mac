// Post a Darwin notification: notify-post <name> [number]. yabai signals (yabairc) and skhd scripts use it to ping
// yabai-helper; a number is set as the notification's state first (e.g. the Space for wm.move).
// /usr/bin/notifyutil does the same but takes ~100 ms, this takes ~1 ms. Built to ~/.local/bin/notify-post by setup.sh.
#include <notify.h>
#include <stdlib.h>

int main(int argc, char **argv) {
	if (argc < 2) return 1;
	if (argc > 2) {
		int token;
		if (notify_register_check(argv[1], &token) != NOTIFY_STATUS_OK) return 1;
		notify_set_state(token, strtoull(argv[2], NULL, 10));
	}
	return notify_post(argv[1]);
}
