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

$(STAMP)/rootfs.done: $(STAMP)/busybox.built $(STAMP)/profile \
                      $(if $(filter minimal,$(PROFILE)),$(STAMP)/ark.built scripts/lilith.sh scripts/sudo-wrapper.sh)
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
	  "alias l='ls -lah'" \
	  "alias c='clear'" \
	  'export EDITOR=vi' \
	  > $(ROOTFS)/root/.ashrc

ifeq ($(PROFILE),minimal)
	@echo '==> minimal: accounts, hostname ($(MIN_HOSTNAME)), user $(MIN_USER)'
	mkdir -p $(UHOME) $(ROOTFS)/usr/bin $(ROOTFS)/usr/share/udhcpc

	printf '%s\n' '[SUID]' \
	  'su = ssx root.root' \
	  'passwd = ssx root.root' > $(ROOTFS)/etc/busybox.conf
	chmod 600 $(ROOTFS)/etc/busybox.conf
	chmod 4755 $(ROOTFS)/bin/busybox

	cp $(ROOTFS)/root/.profile $(ROOTFS)/root/.ashrc $(UHOME)/
	cp $(ARK_BIN) $(ROOTFS)/usr/bin/ark
	cp $(BUSYBOX_SRC)/examples/udhcp/simple.script \
	    $(ROOTFS)/usr/share/udhcpc/default.script
	chmod 755 $(ROOTFS)/usr/share/udhcpc/default.script
	cp $(addprefix scripts/,$(HOME_SCRIPTS)) $(UHOME)/
	chmod 755 $(addprefix $(UHOME)/,$(HOME_SCRIPTS))

	rm -f $(ROOTFS)/bin/wget $(ROOTFS)/usr/bin/wget
	cp scripts/wget-wrapper.sh $(ROOTFS)/usr/bin/wget
	chmod 755 $(ROOTFS)/usr/bin/wget

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
