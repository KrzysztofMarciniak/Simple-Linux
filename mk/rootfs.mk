# ---- rootfs ----------------------------------------------------------------
UHOME        := $(ROOTFS)/home/$(MIN_USER)
HOME_SCRIPTS := connect-eth0.sh connect-wifi.sh ark-add-test-repo.sh

# Profile-specific parts of /etc/inittab.
LOGIN_HINT     := root
HOSTNAME_LINE  :=
EXTRA_SERVICES :=

# Shipped but disabled; turn on with: lilith start ntpd
define NTPD_SERVICE
#lilith:ntpd
#::respawn:/usr/sbin/ntpd -n -p pool.ntp.org
endef

ifeq ($(PROFILE),minimal)
LOGIN_HINT     := root or $(MIN_USER)
HOSTNAME_LINE  := ::sysinit:/bin/hostname -F /etc/hostname
EXTRA_SERVICES := $(NTPD_SERVICE)
endif

define INITTAB
::sysinit:/bin/mkdir -p /proc /sys /dev /tmp
::sysinit:/bin/mount -t proc proc /proc
::sysinit:/bin/mount -t sysfs sysfs /sys
::sysinit:/bin/mount -t devtmpfs devtmpfs /dev
::sysinit:/bin/mount -t tmpfs tmpfs /tmp
::sysinit:/sbin/mdev -s
$(HOSTNAME_LINE)
::sysinit:/bin/cat /etc/issue

# ---- services (managed by lilith) ----
#lilith:mdev
::respawn:/sbin/mdev -df
#lilith:crond
#::respawn:/usr/sbin/crond -f -c /etc/crontabs
$(EXTRA_SERVICES)
#lilith-end

::respawn:-/bin/login

::ctrlaltdel:/sbin/reboot

::shutdown:/bin/sync
::shutdown:/bin/umount -a -r
::shutdown:/bin/sync
endef

export INITTAB

$(STAMP)/rootfs.done: $(STAMP)/busybox.built $(STAMP)/profile $(CURDIR)/mk/rootfs.mk $(CURDIR)/config.mk \
                      $(if $(filter minimal,$(PROFILE)),$(STAMP)/ark.built scripts/lilith.sh scripts/sudo-wrapper.sh $(addprefix scripts/,$(HOME_SCRIPTS)))
	@echo '==> generating rootfs (profile: $(PROFILE))'
	rm -rf $(ROOTFS)/etc $(ROOTFS)/root $(ROOTFS)/home
	mkdir -p $(addprefix $(ROOTFS)/,proc dev tmp etc root etc/crontabs)

	: > $(ROOTFS)/etc/crontabs/root
	chmod 600 $(ROOTFS)/etc/crontabs/root

	printf '%s\n' "$$INITTAB" > $(ROOTFS)/etc/inittab

	# boot logo: https://gist.github.com/nimaid/86e2a55bc6515409ccd9659d1e8e1801
	printf '%s\n' \
	  '      __' \
	  '     /\ \' \
	  '    /  \ \' \
	  '   / /\ \ \' \
	  '  / / /\ \ \' \
	  ' / / /__\_\ \' \
	  '/ / /________\' \
	  '\/___________/' \
      'Simple Linux' \
	  > $(ROOTFS)/etc/issue

	printf '%s\n' \
	  'export PATH=$$HOME/.local/bin:$$HOME/.ark/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin' \
	  'export ENV="$$HOME/.ashrc"' \
	  > $(ROOTFS)/etc/profile

	printf '%s\n' 'export ENV="$$HOME/.ashrc"' > $(ROOTFS)/root/.profile
	printf '%s\n' \
	  '# SimpleLinux ash configuration' \
	  "PS1='\\[\\e[31m\\]\\$$ \\[\\e[0m\\]'" \
	  'export HISTFILE="$$HOME/.ash_history"' \
	  'export HISTSIZE=200' \
	  'export HISTFILESIZE=200' \
	  "alias l='ls -lahpF --full-time --color=always'" \
	  "alias c='clear'" \
	  "alias dhcp='udhcpc'" \
	  "alias dhcpcd='udhcpc'" \
	  'export EDITOR=vi' \
	  'alias ..="cd .."' \
	  'alias ...="cd ../.."' \
	  'alias cp="cp -i"' \
	  'alias mv="mv -i"' \
	  'alias hex="xxd"' \
	  'alias hexx="hexdump"' \
	  '# Limited ifconfig-backed ip compatibility; routes and address deletion are unsupported.' \
	  'ip_ipv4_mask() {' \
	  '    prefix=$$1' \
	  '    while [ "$$prefix" != 0 ] && [ "$${prefix#0}" != "$$prefix" ]; do prefix=$${prefix#0}; done' \
	  '    case "$$prefix" in ""|*[!0-9]*|???*) return 2 ;; esac' \
	  '    [ "$$prefix" -le 32 ] 2>/dev/null || return 2' \
	  '    mask=' \
	  '    part=0' \
	  '    while [ "$$part" -lt 4 ]; do' \
	  '        bits=$$((prefix - part * 8))' \
	  '        if [ "$$bits" -ge 8 ]; then octet=255; elif [ "$$bits" -le 0 ]; then octet=0; else octet=$$((256 - (1 << (8 - bits)))); fi' \
	  '        [ "$$part" -eq 0 ] || mask="$$mask."' \
	  '        mask="$$mask$$octet"' \
	  '        part=$$((part + 1))' \
	  '    done' \
	  '    printf "%s\n" "$$mask"' \
	  '}' \
	  'ip() {' \
	  '    [ "$$#" -gt 0 ] || { echo "Usage: ip {addr|address|link} ..." >&2; return 2; }' \
	  '    case "$$1" in' \
	  '        addr|address)' \
	  '            shift' \
	  '            case "$$1" in' \
	  '                ""|show|list)' \
	  '                    [ "$$1" ] && shift' \
	  '                    if [ "$$1" = dev ] && [ -n "$$2" ] && [ "$$#" -eq 2 ]; then' \
	  '                        command ifconfig "$$2"' \
	  '                    elif [ -z "$$1" ]; then' \
	  '                        command ifconfig -a' \
	  '                    else' \
	  '                        echo "ip addr: supported form is show [dev IFACE]" >&2; return 2' \
	  '                    fi ;;' \
	  '                add)' \
	  '                    shift' \
	  '                    cidr=$$1' \
	  '                    case "$$cidr" in */*) ;; *) echo "ip addr add requires IPv4 CIDR (for example 192.0.2.10/24)" >&2; return 2 ;; esac' \
	  '                    address=$${cidr%/*}' \
	  '                    prefix=$${cidr##*/}' \
	  '                    case "$$address" in ""|*[!0-9.]*) echo "ip addr add: expected an IPv4 address" >&2; return 2 ;; esac' \
	  '                    mask=$$(ip_ipv4_mask "$$prefix") || { echo "ip addr add: invalid IPv4 prefix: $$prefix" >&2; return 2; }' \
	  '                    shift' \
	  '                    [ "$$1" = dev ] && [ -n "$$2" ] || { echo "ip addr add: expected dev IFACE" >&2; return 2; }' \
	  '                    shift' \
	  '                    iface=$$1' \
	  '                    shift' \
	  '                    [ "$$#" -eq 0 ] || { echo "ip addr add: extra arguments are unsupported" >&2; return 2; }' \
	  '                    command ifconfig "$$iface" "$$address" netmask "$$mask" up ;;' \
	  '                *) echo "ip addr: supported forms are show [dev IFACE] and add IPv4/PREFIX dev IFACE" >&2; return 2 ;;' \
	  '            esac ;;' \
	  '        link)' \
	  '            shift' \
	  '            case "$$1" in' \
	  '                ""|show|list)' \
	  '                    [ "$$1" ] && shift' \
	  '                    if [ "$$1" = dev ] && [ -n "$$2" ] && [ "$$#" -eq 2 ]; then' \
	  '                        command ifconfig "$$2"' \
	  '                    elif [ -z "$$1" ]; then' \
	  '                        command ifconfig -a' \
	  '                    else' \
	  '                        echo "ip link: supported form is show [dev IFACE]" >&2; return 2' \
	  '                    fi ;;' \
	  '                set)' \
	  '                    shift' \
	  '                    [ "$$1" = dev ] && shift' \
	  '                    iface=$$1' \
	  '                    action=$$2' \
	  '                    case "$$action" in up|down) ;; *) echo "ip link set: supported actions are up and down" >&2; return 2 ;; esac' \
	  '                    [ -n "$$iface" ] && [ "$$#" -eq 2 ] || { echo "ip link set: expected [dev] IFACE up|down" >&2; return 2; }' \
	  '                    command ifconfig "$$iface" "$$action" ;;' \
	  '                *) echo "ip link: supported forms are show [dev IFACE] and set [dev] IFACE up|down" >&2; return 2 ;;' \
	  '            esac ;;' \
	  '        route|neigh|neighbor|rule)' \
	  '            echo "ip: $$1 cannot be emulated by ifconfig" >&2; return 2 ;;' \
	  '        *) echo "ip: supported groups are addr, address, and link (ifconfig-backed)" >&2; return 2 ;;' \
	  '    esac' \
	  '}' \
	  'rm() {' \
	  '    force=0' \
	  '    recursive=0' \
	  '    for arg do' \
	  '        case "$$arg" in' \
	  '            --) break ;;' \
	  '            -*)' \
	  '                case "$$arg" in' \
	  '                    *f*) force=1 ;;' \
	  '                esac' \
	  '                case "$$arg" in' \
	  '                    *r*|*R*) recursive=1 ;;' \
	  '                esac ;;' \
	  '        esac' \
	  '    done' \
	  '    for path do' \
	  '        case "$$path" in -*) continue ;; esac' \
	  '        if [ -L "$$path" ]; then' \
	  '            command rm -f -- "$$path" || return 1' \
	  '        elif [ -d "$$path" ]; then' \
	  '            [ "$$recursive" -eq 1 ] || {' \
	  '                echo "rm: directory requires -r: $$path" >&2' \
	  '                return 1' \
	  '            }' \
	  '            find "$$path" -depth -type f -exec shred -f -n 3 -z -u {} \; || return 1' \
	  '            command rm -rf -- "$$path" || return 1' \
	  '        elif [ -f "$$path" ]; then' \
	  '            shred -f -n 3 -z -u "$$path" || return 1' \
	  '        elif [ "$$force" -eq 0 ]; then' \
	  '            echo "rm: cannot remove: $$path" >&2' \
	  '            return 1' \
	  '        fi' \
	  '    done' \
	  '}' \
	  > $(ROOTFS)/root/.ashrc

	printf '%s\n' \
	  ':set ts=8' \
	  ':set expandtab' \
	  ':set autoindent' \
	  ':set ignorecase' \
	  > $(ROOTFS)/root/.exrc
	chmod 600 $(ROOTFS)/root/.exrc



ifeq ($(PROFILE),minimal)
	@echo '==> minimal: accounts, hostname ($(MIN_HOSTNAME)), user $(MIN_USER)'
	mkdir -p $(UHOME) $(ROOTFS)/usr/bin $(ROOTFS)/usr/share/udhcpc

	printf '%s\n' '[SUID]' \
	  'su = ssx root.root' \
	  'passwd = ssx root.root' > $(ROOTFS)/etc/busybox.conf
	chmod 600 $(ROOTFS)/etc/busybox.conf
	chmod 4755 $(ROOTFS)/bin/busybox

	cp $(ROOTFS)/root/.profile $(ROOTFS)/root/.ashrc $(ROOTFS)/root/.exrc $(UHOME)/
	chmod 600 $(UHOME)/.exrc
	cp $(ARK_BIN) $(ROOTFS)/usr/bin/ark
	cp $(BUSYBOX_SRC)/examples/udhcp/simple.script \
	    $(ROOTFS)/usr/share/udhcpc/default.script
	chmod 755 $(ROOTFS)/usr/share/udhcpc/default.script
	cp $(addprefix scripts/,$(HOME_SCRIPTS)) $(UHOME)/
	chmod 755 $(addprefix $(UHOME)/,$(HOME_SCRIPTS))

	rm -f $(ROOTFS)/bin/sudo $(ROOTFS)/bin/doas \
	      $(ROOTFS)/usr/bin/sudo $(ROOTFS)/usr/bin/doas
	cp scripts/sudo-wrapper.sh $(ROOTFS)/usr/bin/sudo
	chmod 755 $(ROOTFS)/usr/bin/sudo
	ln -sf sudo $(ROOTFS)/usr/bin/doas

	cp scripts/lilith.sh $(ROOTFS)/usr/bin/lilith
	chmod 755 $(ROOTFS)/usr/bin/lilith

	: > $(ROOTFS)/etc/resolv.conf
	echo '$(MIN_HOSTNAME)' > $(ROOTFS)/etc/hostname
	printf '%s\n' \
	  'NAME="Simple Linux"' \
	  'ID=simplelinux' \
	  'PRETTY_NAME="Simple Linux"' \
	  > $(ROOTFS)/etc/os-release

	days=$$(( $$(date +%s) / 86400 )); \
	rh=$$(printf '%s' '$(ROOT_PASSWD)' | openssl passwd -6 -stdin); \
	uh=$$(printf '%s' '$(USER_PASS)' | openssl passwd -6 -stdin); \
	printf '%s\n' \
	  'root:x:0:0:root:/root:/bin/sh' \
	  '$(MIN_USER):x:$(MIN_UID):$(MIN_GID):$(MIN_USER):/home/$(MIN_USER):/bin/sh' \
	  > $(ROOTFS)/etc/passwd; \
	printf '%s\n' 'root:x:0:' '$(MIN_USER):x:$(MIN_GID):' > $(ROOTFS)/etc/group; \
	printf 'root:%s:%s:0:99999:7:::\n%s:%s:%s:0:99999:7:::\n' \
	  "$$rh" "$$days" '$(MIN_USER)' "$$uh" "$$days" > $(ROOTFS)/etc/shadow; \
	chmod 600 $(ROOTFS)/etc/shadow

	printf '%s\n' \
	  'null    0:0 666' \
	  'zero    0:0 666' \
	  'full    0:0 666' \
	  'random  0:0 666' \
	  'urandom 0:0 666' \
	  'tty     0:0 666' \
	  'ptmx    0:0 666' \
	  > $(ROOTFS)/etc/mdev.conf
else
	echo 'root::0:0:root:/root:/bin/sh' > $(ROOTFS)/etc/passwd
endif

	test -f $(ROOTFS)$(MUSL_LD) || { echo 'ERROR: musl loader missing from rootfs' >&2; exit 1; }
	ln -sf bin/busybox $(ROOTFS)/init
	@touch $@
