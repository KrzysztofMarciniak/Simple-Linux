#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root." >&2
    exit 1
fi

ifconfig eth0 up
exec udhcpc -q -i eth0 -s /usr/share/udhcpc/default.script
