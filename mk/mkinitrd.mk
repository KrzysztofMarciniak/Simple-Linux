# ---- BusyBox initramfs generator and target kernel modules (Minimal) ------
KMOD_BUILD := $(B)/kmod-build
KMOD_INST := $(B)/kmod-install
KMOD_CROSS_FILE := $(B)/kmod-cross.ini
KMOD_CC := $(CC_SYS_CACHED) -fuse-ld=lld -B$(abspath $(LLVM_INST))/usr/bin
KMOD_LDFLAGS := -fuse-ld=lld -B$(abspath $(LLVM_INST))/usr/bin \
                -rtlib=compiler-rt -unwindlib=none
KMOD_EMPTY :=
KMOD_SPACE := $(KMOD_EMPTY) $(KMOD_EMPTY)
KMOD_COMMA := ,
KMOD_CC_ARGS := $(subst $(KMOD_SPACE),$(KMOD_COMMA) ,$(foreach arg,$(KMOD_CC),'$(arg)'))
KMOD_LDFLAGS_ARGS := $(subst $(KMOD_SPACE),$(KMOD_COMMA) ,$(foreach arg,$(KMOD_LDFLAGS),'$(arg)'))
KERNEL_MODULES_INST := $(B)/kernel-modules-install
MKINITRD_BUILD := $(B)/mkinitrd-build
MKINITRD_INST := $(B)/mkinitrd-install
KERNEL_RELEASE := $(LINUX_VERSION)

.PHONY: mkinitrd
ifeq ($(PROFILE),minimal)
mkinitrd: $(STAMP)/mkinitrd.rootfs

$(STAMP)/kmod.built: $(STAMP)/kmod.unpacked $(STAMP)/musl.built $(STAMP)/llvm.built \
                     $(STAMP)/target.ccache $(CURDIR)/mk/mkinitrd.mk $(CURDIR)/config.mk
	rm -rf $(KMOD_BUILD) $(KMOD_INST)
	mkdir -p $(KMOD_BUILD)
	printf '%s\n' \
	  '[binaries]' \
	  "c = [$(KMOD_CC_ARGS)]" \
	  "ar = '$(abspath $(LLVM_INST))/usr/bin/llvm-ar'" \
	  "ranlib = '$(abspath $(LLVM_INST))/usr/bin/llvm-ranlib'" \
	  '[built-in options]' \
	  "c_args = ['-O2']" \
	  "c_link_args = [$(KMOD_LDFLAGS_ARGS)]" \
	  '[host_machine]' \
	  "system = 'linux'" \
	  "cpu_family = 'x86_64'" \
	  "cpu = 'x86_64'" \
	  "endian = 'little'" \
	  '[properties]' \
	  'needs_exe_wrapper = true' > $(KMOD_CROSS_FILE)
	meson setup \
	    --cross-file=$(KMOD_CROSS_FILE) \
	    --prefix=/usr --libdir=lib --sysconfdir=/etc \
	    --buildtype=release \
	    -Dmanpages=false -Ddocs=false -Dbuild-tests=false \
	    -Dbashcompletiondir=no -Dfishcompletiondir=no -Dzshcompletiondir=no \
	    -Dzstd=disabled -Dxz=disabled -Dzlib=disabled -Dopenssl=disabled \
	    $(KMOD_BUILD) $(KMOD_SRC)
	meson compile -C $(KMOD_BUILD) --jobs $(JOBS)
	DESTDIR=$(abspath $(KMOD_INST)) meson install -C $(KMOD_BUILD)
	test -x $(KMOD_INST)/usr/bin/kmod
	test -x $(KMOD_INST)/usr/sbin/modprobe
	test -x $(KMOD_INST)/usr/sbin/modinfo
	test -x $(KMOD_INST)/usr/sbin/depmod
	test -e $(KMOD_INST)/usr/lib/libkmod.so.2
	@touch $@

$(STAMP)/kernel.modules.built: $(STAMP)/kernel.built \
                               $(CURDIR)/mk/mkinitrd.mk
	rm -rf $(KERNEL_MODULES_INST)
	$(MAKE) -C $(LINUX_SRC) O=$(KOUT) LLVM=1 ARCH=$(KARCH) \
	  CC="$(strip $(if $(filter ON,$(TARGET_CCACHE)),$(CCACHE)) clang)" \
	  -j$(KERNEL_JOBS) modules
	$(MAKE) -C $(LINUX_SRC) O=$(KOUT) LLVM=1 ARCH=$(KARCH) \
	  INSTALL_MOD_PATH=$(abspath $(KERNEL_MODULES_INST)) \
	  DEPMOD=depmod modules_install
	test -f $(KERNEL_MODULES_INST)/lib/modules/$(KERNEL_RELEASE)/modules.dep
	@touch $@

$(STAMP)/mkinitrd.built: $(STAMP)/mkinitrd.unpacked \
                         $(CURDIR)/patches/mkinitrd-kmod.patch \
                         $(CURDIR)/mk/mkinitrd.mk
	rm -rf $(MKINITRD_BUILD) $(MKINITRD_INST)
	mkdir -p $(MKINITRD_BUILD)
	cp -a $(MKINITRD_SRC)/. $(MKINITRD_BUILD)/
	patch -d $(MKINITRD_BUILD) -p1 < $(CURDIR)/patches/mkinitrd-kmod.patch
	install -D -m 0755 $(MKINITRD_BUILD)/mkinitrd \
	  $(MKINITRD_INST)/usr/bin/mkinitrd
	install -D -m 0644 $(MKINITRD_BUILD)/init \
	  $(MKINITRD_INST)/usr/share/mkinitrd/init
	mkdir -p $(MKINITRD_INST)/usr/share/mkinitrd/hooks
	cp -a $(MKINITRD_BUILD)/hooks/. $(MKINITRD_INST)/usr/share/mkinitrd/hooks/
	install -D -m 0644 $(MKINITRD_BUILD)/mkinitrd.conf \
	  $(MKINITRD_INST)/etc/mkinitrd.conf
	install -D -m 0644 $(MKINITRD_BUILD)/mkinitrd.8 \
	  $(MKINITRD_INST)/usr/share/man/man8/mkinitrd.8
	install -D -m 0644 $(MKINITRD_BUILD)/LICENSE \
	  $(MKINITRD_INST)/usr/share/licenses/mkinitrd/LICENSE
	@touch $@

$(STAMP)/mkinitrd.rootfs: $(STAMP)/kmod.built $(STAMP)/kernel.modules.built \
                          $(STAMP)/mkinitrd.built $(STAMP)/rootfs.done \
                          $(CURDIR)/mk/mkinitrd.mk
	cp -a $(KMOD_INST)/. $(ROOTFS)/
	cp -a $(KERNEL_MODULES_INST)/. $(ROOTFS)/
	cp -a $(MKINITRD_INST)/. $(ROOTFS)/
	mkdir -p $(ROOTFS)/usr/bin
	ln -sf $(MUSL_LD) $(ROOTFS)/usr/bin/ldd
	test -x $(ROOTFS)/usr/bin/mkinitrd
	test -x $(ROOTFS)/usr/sbin/modprobe
	test -f $(ROOTFS)/lib/modules/$(KERNEL_RELEASE)/modules.dep
	@touch $@
endif
