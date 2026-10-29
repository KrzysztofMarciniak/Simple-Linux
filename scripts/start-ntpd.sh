#!/bin/sh
#
echo 'using pool.ntp.org...'

# Wait for network and DNS.
while ! nslookup pool.ntp.org >/dev/null 2>&1; do
    sleep 2
done

# Start NTP client; ntpd daemonizes by default.
exec ntpd -p pool.ntp.org
