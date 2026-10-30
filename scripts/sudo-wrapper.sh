#!/bin/sh
# sudo/doas shim: run a command as root via busybox su.
[ $# -gt 0 ] || { echo "usage: ${0##*/} <command> [args...]" >&2; exit 1; }
[ "$(id -u)" = 0 ] && exec "$@"

quote() { printf "'%s'" "$(printf %s "$1" | sed "s/'/'\\\\''/g")"; }

cmd=
for a in "$@"; do cmd="$cmd $(quote "$a")"; done
exec su root -c "$cmd"
