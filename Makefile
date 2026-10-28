# SimpleLinux: linux + musl + clang + busybox (init)
#   make          build the ISO (profile = last one built, bare by default)
#   make bare     build the Bare profile ISO
#   make minimal  build the Minimal profile ISO (asks for passwords)
#   make rootfs   rebuild rootfs/initramfs/ISO for the current profile
#   make clean    remove build output (keeps downloads/)

include config.mk

.DEFAULT_GOAL := iso
.PHONY: iso clean rootfs bare minimal FORCE

# bash is needed for `read -s` in the password prompt
SHELL := /bin/bash

DL      := $(CURDIR)/downloads
B       := $(CURDIR)/build
SRC     := $(B)/src
STAMP   := $(B)/stamps
SYSROOT := $(B)/sysroot
ROOTFS  := $(B)/rootfs
KOUT    := $(B)/linux-out
INITRD  := $(B)/initramfs.gz
ISO     := $(CURDIR)/$(NAME)-$(VERSION).iso
CREDS   := $(B)/credentials

# ---- profiles --------------------------------------------------------------
# PROFILE: bare | minimal. If not given, reuse the last built profile.
ifndef PROFILE
PROFILE := $(or $(shell cat $(STAMP)/profile 2>/dev/null),bare)
endif

# Minimal profile defaults
MIN_USER     ?= 0x00
MIN_UID      ?= 1000
MIN_GID      ?= $(MIN_UID)
MIN_HOSTNAME ?= antarctica

GCC_DIR := $(patsubst %/,%,$(dir $(shell gcc -print-file-name=crtbeginT.o)))
CC_SYS  := $(CLANG) --target=$(TARGET) --sysroot=$(SYSROOT) --gcc-install-dir=$(GCC_DIR) -static

# download + unpack: $(call PKG,name,url)
define PKG
$(DL)/$(notdir $(2)):
	@mkdir -p $(DL)
	curl -fL --retry 3 -o $$@.part $(2)
	@mv $$@.part $$@
$(STAMP)/$(1).unpacked: $(DL)/$(notdir $(2))
	@mkdir -p $(SRC) $(STAMP)
	tar -xf $$< -C $(SRC)
	@touch $$@
endef

$(eval $(call PKG,linux,$(LINUX_URL)))
$(eval $(call PKG,musl,$(MUSL_URL)))
$(eval $(call PKG,busybox,$(BUSYBOX_URL)))

LINUX_SRC   := $(SRC)/linux-$(LINUX_VERSION)
MUSL_SRC    := $(SRC)/musl-$(MUSL_VERSION)
BUSYBOX_SRC := $(SRC)/busybox-$(BUSYBOX_VERSION)

# ---- profile targets -------------------------------------------------------
bare:
	@$(MAKE) --no-print-directory PROFILE=bare iso

# Ask for the passwords first (before the long build), then build.
minimal:
	@rm -f $(CREDS)
	@$(MAKE) --no-print-directory PROFILE=minimal $(CREDS)
	@$(MAKE) --no-print-directory PROFILE=minimal iso

# Remember which profile the rootfs was generated for. The file is only
# touched when the profile changes, so switching profiles regenerates
# the rootfs, initramfs and ISO.
$(STAMP)/profile: FORCE
	@mkdir -p $(STAMP)
	@echo '$(PROFILE)' | cmp -s - $@ || echo '$(PROFILE)' > $@

# ---- credentials (minimal profile) -----------------------------------------
# Stores only SHA-512 crypt hashes (line 1: root, line 2: $(MIN_USER)).
$(CREDS):
	@mkdir -p $(B)
	@set -e; \
	[ -t 0 ] || { echo 'make minimal needs an interactive terminal for the password prompts' >&2; exit 1; }; \
	hash() { \
	  if command -v openssl >/dev/null 2>&1; then openssl passwd -6 -stdin; \
	  elif command -v mkpasswd >/dev/null 2>&1; then mkpasswd -m sha-512 -s; \
	  else echo 'error: openssl or mkpasswd is required on the host' >&2; return 1; fi; \
	}; \
	ask() { \
	  while :; do \
	    printf '%s: ' "$$1" >&2; read -r -s p1; echo >&2; \
	    if [ -z "$$p1" ]; then echo 'Password must not be empty.' >&2; continue; fi; \
	    printf 'Retype %s: ' "$$1" >&2; read -r -s p2; echo >&2; \
	    [ "$$p1" = "$$p2" ] && break; \
	    echo 'Passwords do not match, try again.' >&2; \
	  done; \
	  printf '%s' "$$p1" | hash; \
	}; \
	echo 'Minimal profile: user $(MIN_USER), hostname $(MIN_HOSTNAME)' >&2; \
	rh=$$(ask 'Root password'); \
	uh=$$(ask 'Password for $(MIN_USER)'); \
	( umask 077; printf '%s\n%s\n' "$$rh" "$$uh" > $@.tmp ); \
	mv $@.tmp $@

# ---- kernel headers (for musl and userland) --------------------------------
$(STAMP)/headers.built: $(STAMP)/linux.unpacked
	@mkdir -p $(KOUT) $(SYSROOT)/usr
	$(MAKE) -C $(LINUX_SRC) O=$(KOUT) LLVM=1 ARCH=$(KARCH) \
	    INSTALL_HDR_PATH=$(SYSROOT)/usr headers_install
	@touch $@

# ---- kernel ----------------------------------------------------------------
$(STAMP)/kernel.built: $(STAMP)/linux.unpacked
	@mkdir -p $(KOUT)
	$(MAKE) -C $(LINUX_SRC) O=$(KOUT) LLVM=1 ARCH=$(KARCH) defconfig
	$(MAKE) -C $(LINUX_SRC) O=$(KOUT) LLVM=1 ARCH=$(KARCH) -j$(JOBS) bzImage
	@touch $@

# ---- musl ------------------------------------------------------------------
$(STAMP)/musl.built: $(STAMP)/musl.unpacked $(STAMP)/headers.built
	cd $(MUSL_SRC) && \
	  CC="$(CLANG) --target=$(TARGET)" ./configure --prefix=/usr --disable-shared && \
	  $(MAKE) -j$(JOBS) && $(MAKE) DESTDIR=$(SYSROOT) install
	@touch $@

# ---- busybox (userland + init) ---------------------------------------------
$(STAMP)/busybox.built: $(STAMP)/busybox.unpacked $(STAMP)/musl.built
	cd $(BUSYBOX_SRC) && \
	  $(MAKE) CC="$(CC_SYS)" HOSTCC=cc defconfig && \
	  sed -i -e 's/^.*CONFIG_STATIC[= ].*$$/CONFIG_STATIC=y/' \
	         -e 's/^.*CONFIG_TC[= ].*$$/CONFIG_TC=n/' .config && \
	  yes "" | $(MAKE) CC="$(CC_SYS)" HOSTCC=cc oldconfig && \
	  $(MAKE) -j$(JOBS) CC="$(CC_SYS)" HOSTCC=cc && \
	  $(MAKE) CC="$(CC_SYS)" HOSTCC=cc CONFIG_PREFIX=$(ROOTFS) install
	@touch $@

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

$(STAMP)/rootfs.done: $(STAMP)/busybox.built $(STAMP)/profile $(if $(filter minimal,$(PROFILE)),$(CREDS))
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
	mkdir -p $(ROOTFS)/home/$(MIN_USER)
	cp $(ROOTFS)/root/.profile $(ROOTFS)/root/.ashrc $(ROOTFS)/home/$(MIN_USER)/
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

# ---- initramfs (gen_init_cpio creates /dev nodes without root) -------------
$(INITRD): $(STAMP)/rootfs.done $(STAMP)/linux.unpacked
	cc -o $(B)/gen_init_cpio $(LINUX_SRC)/usr/gen_init_cpio.c
	cd $(ROOTFS) && { \
	  find . -mindepth 1 -type d -printf 'dir /%P %m 0 0\n'; \
	  find . -type f -printf 'file /%P %p %m 0 0\n'; \
	  find . -type l -printf 'slink /%P %l %m 0 0\n'; \
	  echo 'nod /dev/console 0600 0 0 c 5 1'; \
	  echo 'nod /dev/null 0666 0 0 c 1 3'; \
	} > $(B)/initramfs.list
ifeq ($(PROFILE),minimal)
	sed -E -i 's@^((dir|file) /home/$(MIN_USER)(/[^ ]*)? .*) 0 0$$@\1 $(MIN_UID) $(MIN_GID)@' $(B)/initramfs.list
endif
	cd $(ROOTFS) && $(B)/gen_init_cpio $(B)/initramfs.list | gzip -9 > $@

# ---- ISO -------------------------------------------------------------------
iso: $(ISO)
$(ISO): $(STAMP)/kernel.built $(INITRD)
	rm -rf $(B)/iso
	mkdir -p $(B)/iso/boot/grub
	cp $(KOUT)/arch/$(KARCH)/boot/bzImage $(B)/iso/boot/vmlinuz
	cp $(INITRD) $(B)/iso/boot/initramfs.gz
	printf 'set timeout=0\nmenuentry "%s" {\n  linux /boot/vmlinuz console=tty0 console=ttyS0\n  initrd /boot/initramfs.gz\n}\n' \
	    "$(NAME)" > $(B)/iso/boot/grub/grub.cfg
	grub-mkrescue -o $@ $(B)/iso

clean:
	rm -rf $(B) $(ISO)

FORCE:

rootfs:
	rm -f $(STAMP)/rootfs.done $(INITRD) $(ISO)
	$(MAKE) PROFILE=$(PROFILE) iso
