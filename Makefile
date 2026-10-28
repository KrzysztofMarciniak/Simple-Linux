# SimpleLinux: linux + musl + clang + busybox (init)
#   make        build the ISO
#   make clean  remove build output (keeps downloads/)

include config.mk

.DEFAULT_GOAL := iso
.PHONY: iso clean rootfs

DL      := $(CURDIR)/downloads
B       := $(CURDIR)/build
SRC     := $(B)/src
STAMP   := $(B)/stamps
SYSROOT := $(B)/sysroot
ROOTFS  := $(B)/rootfs
KOUT    := $(B)/linux-out
INITRD  := $(B)/initramfs.gz
ISO     := $(CURDIR)/$(NAME)-$(VERSION).iso

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

::sysinit:/bin/echo "Welcome to SimpleLinux"
::sysinit:/bin/echo "login as root"

::respawn:-/bin/login

::ctrlaltdel:/sbin/reboot

::shutdown:/bin/sync
::shutdown:/bin/umount -a -r
::shutdown:/bin/sync
endef

export INITTAB

$(STAMP)/rootfs.done: $(STAMP)/busybox.built
	mkdir -p $(ROOTFS)/proc $(ROOTFS)/dev $(ROOTFS)/tmp $(ROOTFS)/etc $(ROOTFS)/root
	printf '%s\n' "$$INITTAB" > $(ROOTFS)/etc/inittab
	echo 'root::0:0:root:/root:/bin/sh' > $(ROOTFS)/etc/passwd

	printf '%s\n' \
	  'HOME=/root' \
	  'export HOME' \
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


rootfs:
	rm -f $(STAMP)/rootfs.done $(INITRD) $(ISO)
	$(MAKE) iso
