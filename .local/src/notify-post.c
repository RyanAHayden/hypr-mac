// Post a Darwin notification: notify-post <name>. yabai signals (yabairc) use it to ping yabai-helper;
// /usr/bin/notifyutil does the same but takes ~100 ms, this takes ~1 ms. Built to ~/.local/bin/notify-post by setup.sh.
#include <notify.h>

int main(int argc, char **argv) { return argc > 1 ? notify_post(argv[1]) : 1; }
