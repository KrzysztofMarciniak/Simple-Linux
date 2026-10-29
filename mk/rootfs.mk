# ---- rootfs ----------------------------------------------------------------
UHOME        := $(ROOTFS)/home/$(MIN_USER)
HOME_SCRIPTS := connect-eth0.sh connect-wifi.sh ark-add-test-repo.sh start-ntpd.sh

# Profile-specific parts of /etc/inittab.
LOGIN_HINT    := root
HOSTNAME_LINE :=
ifeq ($(PROFILE),minimal)
LOGIN_HINT    := root or $(MIN_USER)
HOSTNAME_LINE := ::sysinit:/bin/hostname -F /etc/hostname
endif

define INITTAB
::sysinit:/bin/mkdir -p /proc /sys /dev /tmp
::sysinit:/bin/mount -t proc proc /proc
::sysinit:/bin/mount -t sysfs sysfs /sys
::sysinit:/bin/mount -t devtmpfs devtmpfs /dev
::sysinit:/bin/mount -t tmpfs tmpfs /tmp
::sysinit:/sbin/mdev -s
::respawn:/sbin/mdev -df
::respawn:/usr/sbin/crond -f -c /etc/crontabs
$(HOSTNAME_LINE)

::respawn:-/bin/login

::ctrlaltdel:/sbin/reboot

::shutdown:/bin/sync
::shutdown:/bin/umount -a -r
::shutdown:/bin/sync
endef

export INITTAB

$(STAMP)/rootfs.done: $(STAMP)/busybox.built $(STAMP)/profile \
                      $(if $(filter minimal,$(PROFILE)),$(CREDS) $(STAMP)/ark.built)
	@echo '==> generating rootfs (profile: $(PROFILE))'
	rm -rf $(ROOTFS)/etc $(ROOTFS)/root $(ROOTFS)/home
	mkdir -p $(addprefix $(ROOTFS)/,proc dev tmp etc root etc/crontabs)
	: > $(ROOTFS)/etc/crontabs/root
	chmod 600 $(ROOTFS)/etc/crontabs/root
	printf '%s\n' "$$INITTAB" > $(ROOTFS)/etc/inittab

	printf '%s\n' \
	  'export PATH=/bin:/sbin:/usr/bin:/usr/sbin' \
	  'export ENV="$$HOME/.ashrc"' \
	  > $(ROOTFS)/etc/profile

	printf '%s\n' 'export ENV="$$HOME/.ashrc"' > $(ROOTFS)/root/.profile

	printf '%s\n' \
	  '# SimpleLinux ash configuration' \
	  "echo 'Booted into Simple Linux'" \
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

	: > $(ROOTFS)/etc/resolv.conf
	echo '$(MIN_HOSTNAME)' > $(ROOTFS)/etc/hostname
	printf '%s\n' 'export PS1="\u@\h:\w\$$ "' >> $(ROOTFS)/etc/profile
	{ read -r rh; read -r uh; } < $(CREDS); \
	days=$$(( $$(date +%s) / 86400 )); \
	printf '%s\n' \
	  'root:x:0:0:root:/root:/bin/sh' \
	  '$(MIN_USER):x:$(MIN_UID):$(MIN_GID):$(MIN_USER):/home/$(MIN_USER):/bin/sh' \
	  > $(ROOTFS)/etc/passwd; \
	printf '%s\n' 'root:x:0:' '$(MIN_USER):x:$(MIN_GID):' > $(ROOTFS)/etc/group; \
	printf 'root:%s:%s:0:99999:7:::\n%s:%s:%s:0:99999:7:::\n' \
	  "$$rh" "$$days" '$(MIN_USER)' "$$uh" "$$days" > $(ROOTFS)/etc/shadow; \
	chmod 600 $(ROOTFS)/etc/shadow
else
	echo 'root::0:0:root:/root:/bin/sh' > $(ROOTFS)/etc/passwd
endif

	ln -sf bin/busybox $(ROOTFS)/init
	@touch $@
