#!/bin/sh
# Replaces BusyBox's wget link. BusyBox https wget finishes the download, then
# crashes in musl's exit(). If it died from a signal but wrote the -O file,
# report success.
out=
prev=
for a in "$@"; do
    case $a in -O?*) out=${a#-O} ;; esac
    case $prev in -O|-[!-]*O) out=$a ;; esac
    prev=$a
done

/bin/busybox wget "$@"
rc=$?

if [ "$rc" -gt 128 ] && [ -n "$out" ] && [ "$out" != - ] && [ -s "$out" ]; then
    exit 0
fi
exit "$rc"
