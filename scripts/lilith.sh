#!/bin/sh
# lilith - service layer for SimpleLinux (BusyBox init + /etc/inittab only)
TAB=${LILITH_TAB:-/etc/inittab}
TMP=$TAB.lilith.$$
SELF=$(readlink -f "$0" 2>/dev/null || echo "$0")

die() { echo "lilith: $*" >&2; exit 1; }

usage() {
    cat >&2 <<EOF
usage:
  lilith add "<command [args]>" [name]
  lilith remove <name>
  lilith start  <name>
  lilith stop   <name>
  lilith list
EOF
    exit 1
}

reload() { kill -HUP 1; }
has()    { grep -Fxq "#lilith:$1" "$TAB"; }

quote() { printf "'%s'" "$(printf %s "$1" | sed "s/'/'\\\\''/g")"; }

elevate() {
    cmd=$(quote "$SELF")
    for a in "$@"; do cmd="$cmd $(quote "$a")"; done
    echo "lilith: not root, trying su..." >&2
    su root -c "$cmd"
    exit $?
}

edit() {                                     # edit <remove|stop|start> <name>
    awk -v m="$1" -v n="$2" '
    {
        if (nxt) {
            nxt = 0
            if (m == "remove") next
            if (m == "stop"  && $0 !~ /^#/) { print "#" $0; next }
            if (m == "start" && $0 ~  /^#/) { print substr($0, 2); next }
            print; next
        }
        if ($0 == "#lilith:" n) { nxt = 1; if (m == "remove") next }
        print
    }' "$TAB" > "$TMP" || { rm -f "$TMP"; die "edit failed"; }
    mv "$TMP" "$TAB"
    reload
}

add() {
    [ -n "$1" ] || usage
    cmd=$1
    first=${cmd%% *}
    name=${2:-${first##*/}}
    case $name in ''|*[!A-Za-z0-9_.-]*) die "bad service name '$name'" ;; esac
    has "$name" && die "service '$name' already exists"
    [ -n "$(tail -c1 "$TAB")" ] && echo >> "$TAB"
    printf '#lilith:%s\n::respawn:%s\n' "$name" "$cmd" >> "$TAB"
    reload
    echo "lilith: added '$name'"
}

list() {
    awk '/^#lilith:/ {
        n = substr($0, 9); getline
        st = ($0 ~ /^#/) ? "off" : "on"
        sub(/^#?::respawn:/, "")
        printf "%-12s %-4s %s\n", n, st, $0
    }' "$TAB"
}

[ $# -ge 1 ]  || usage
[ -f "$TAB" ] || die "$TAB not found"

if [ "$1" != list ] && [ "$(id -u)" != 0 ]; then
    elevate "$@"
fi

case $1 in
    add)    shift; add "$@" ;;
    list)   list ;;
    remove|stop|start)
            [ -n "$2" ] || usage
            has "$2" || die "no such service: $2"
            edit "$1" "$2"
            echo "lilith: $1 $2" ;;
    *)      usage ;;
esac
