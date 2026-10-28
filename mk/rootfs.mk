# ---- rootfs: BusyBox init config -------------------------------------------
define INITTAB
::sysinit:/bin/mount -t proc proc /proc
::sysinit:/bin/mount -t devtmpfs devtmpfs /dev
::sysinit:/bin/mount -t tmpfs tmpfs /tmp

::sysinit:/bin/echo ""
::sysinit:/bin/echo ""
::sysinit:/bin/echo "Welcome to SimpleLinux"
::sysinit:/bin/echo "login as root"
::sysinit:/bin/echo ""
::sysinit:/bin/echo ""

::respawn:-/bin/login

::ctrlaltdel:/sbin/reboot

::shutdown:/bin/sync
::shutdown:/bin/umount -a -r
::shutdown:/bin/sync
endef

export INITTAB

MINIMAL_TOOLS := $(STAMP)/ark.built
$(STAMP)/rootfs.done: $(STAMP)/busybox.built $(STAMP)/profile \
                      $(if $(filter minimal,$(PROFILE)),$(CREDS) $(MINIMAL_TOOLS))
	@echo '==> generating rootfs (profile: $(PROFILE))'
	rm -rf $(ROOTFS)/etc $(ROOTFS)/root $(ROOTFS)/home
	mkdir -p $(ROOTFS)/proc $(ROOTFS)/dev $(ROOTFS)/tmp $(ROOTFS)/etc $(ROOTFS)/root
	printf '%s\n' "$$INITTAB" > $(ROOTFS)/etc/inittab
	echo 'root::0:0:root:/root:/bin/sh' > $(ROOTFS)/etc/passwd

	printf '%s\n' \
	  'export PATH=/bin:/sbin:/usr/bin:/usr/sbin' \
	  'export ENV="$$HOME/.ashrc"' \
	  > $(ROOTFS)/etc/profile

	printf '%s\n' \
	  'export ENV="$$HOME/.ashrc"' \
	  > $(ROOTFS)/root/.profile

	printf '%s\n' \
	  '# SimpleLinux ash configuration' \
	  "echo 'Booted into Simple Linux'" \
	  "alias l='ls -lah'" \
	  "alias c='clear'" \
	  'export EDITOR=vi' \
	  > $(ROOTFS)/root/.ashrc

ifeq ($(PROFILE),minimal)
	@echo '==> minimal: accounts, hostname ($(MIN_HOSTNAME)), user $(MIN_USER)'
	mkdir -p $(ROOTFS)/home/$(MIN_USER) $(ROOTFS)/usr/bin \
	    $(ROOTFS)/usr/share/udhcpc
	cp $(ROOTFS)/root/.profile $(ROOTFS)/root/.ashrc $(ROOTFS)/home/$(MIN_USER)/
	cp $(ARK_BIN) $(ROOTFS)/usr/bin/ark
	cp $(BUSYBOX_SRC)/examples/udhcp/simple.script \
	    $(ROOTFS)/usr/share/udhcpc/default.script
	chmod 755 $(ROOTFS)/usr/share/udhcpc/default.script
	cp scripts/connect-eth0.sh scripts/connect-wifi.sh \
	    $(ROOTFS)/home/$(MIN_USER)/
	chmod 755 $(ROOTFS)/home/$(MIN_USER)/connect-eth0.sh \
	    $(ROOTFS)/home/$(MIN_USER)/connect-wifi.sh
	: > $(ROOTFS)/etc/resolv.conf
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
	echo '$(MIN_HOSTNAME)' > $(ROOTFS)/etc/hostname
	echo '::sysinit:/bin/hostname -F /etc/hostname' >> $(ROOTFS)/etc/inittab
	printf '%s\n' 'export PS1="\u@\h:\w\$$ "' >> $(ROOTFS)/etc/profile
	sed -i 's/^::sysinit:\/bin\/echo "login as root"$$/::sysinit:\/bin\/echo "login as root or $(MIN_USER)"/' $(ROOTFS)/etc/inittab
endif

	ln -sf bin/busybox $(ROOTFS)/init
	@touch $@
