# ---- GRUB and xorriso (host ISO tools and musl target tools) ---------------
GRUB_BUILD_CC ?= cc
GRUB_BUILD_TRIPLET := $(shell $(GRUB_BUILD_CC) -dumpmachine)
GRUB_FW_CLANG := $(abspath $(LLVM_INST))/usr/bin/clang
GRUB_FW_TOOLS := $(abspath $(LLVM_INST))/usr/bin
GRUB_FW_LDFLAGS := -fuse-ld=lld -B$(GRUB_FW_TOOLS) -nostdlib -Wl,--no-pie
GRUB_FW_PC_CC := $(GRUB_FW_CLANG) --target=i386-unknown-none-elf \
                 --sysroot=$(abspath $(SYSROOT))
GRUB_FW_EFI_CC := $(GRUB_FW_CLANG) --target=x86_64-unknown-none-elf \
                  --sysroot=$(abspath $(SYSROOT))
# Keep linker-only runtime flags out of GRUB's compile-only -Werror probes.
GRUB_TARGET_CC := $(filter-out -rtlib=compiler-rt -unwindlib=none,$(CC_SYS_CACHED))
GRUB_TARGET_LDFLAGS := -fuse-ld=lld -B$(GRUB_FW_TOOLS) \
                       -L$(LLVM_RUNTIME_LIBDIR) \
                       -Wl,-rpath-link,$(LLVM_RUNTIME_LIBDIR) \
                       -rtlib=compiler-rt -unwindlib=none

GRUB_HOST_LIBBURN_INST := $(B)/libburn-host-install
GRUB_HOST_LIBISOFS_INST := $(B)/libisofs-host-install
GRUB_HOST_LIBISOBURN_INST := $(B)/libisoburn-host-install
GRUB_HOST_INST := $(B)/grub-host-install
GRUB_HOST_EFI_INST := $(B)/grub-host-efi-install
GRUB_HOST_PREFIX := $(abspath $(GRUB_HOST_INST))/usr
GRUB_HOST_LIB := $(GRUB_HOST_LIBBURN_INST)/usr/lib:$(GRUB_HOST_LIBISOFS_INST)/usr/lib:$(GRUB_HOST_LIBISOBURN_INST)/usr/lib
GRUB_HOST_PKGCONFIG := $(GRUB_HOST_LIBBURN_INST)/usr/lib/pkgconfig:$(GRUB_HOST_LIBISOFS_INST)/usr/lib/pkgconfig

GRUB_TARGET_STACK_INST := $(B)/grub-target-stack-install
GRUB_TARGET_LIBBURN_INST := $(GRUB_TARGET_STACK_INST)
GRUB_TARGET_LIBISOFS_INST := $(GRUB_TARGET_STACK_INST)
GRUB_TARGET_LIBISOBURN_INST := $(GRUB_TARGET_STACK_INST)
GRUB_TARGET_INST := $(B)/grub-target-install
GRUB_TARGET_EFI_INST := $(B)/grub-target-efi-install
GRUB_TARGET_PKGCONFIG := $(GRUB_TARGET_STACK_INST)/usr/lib/pkgconfig
GRUB_TARGET_CPPFLAGS := -I$(abspath $(SYSROOT))/usr/include \
                        -I$(abspath $(GRUB_TARGET_STACK_INST))/usr/include
GRUB_TARGET_CFLAGS := -O2 -fno-stack-protector

.PHONY: grub
ifeq ($(PROFILE),minimal)
grub: $(STAMP)/grub.rootfs
endif

# Host xorriso is used by grub-mkrescue during ISO creation.
$(STAMP)/libburn.host.built: $(STAMP)/libburn.unpacked $(CURDIR)/mk/grub.mk $(CURDIR)/mk/sources.mk
	rm -rf $(B)/libburn-host-build $(GRUB_HOST_LIBBURN_INST)
	mkdir -p $(B)/libburn-host-build
	cd $(B)/libburn-host-build && \
	  CC="$(GRUB_BUILD_CC)" CFLAGS="-O2" \
	  $(LIBBURN_SRC)/configure \
	    --prefix=$(abspath $(GRUB_HOST_LIBBURN_INST))/usr \
	    --libdir=$(abspath $(GRUB_HOST_LIBBURN_INST))/usr/lib \
	    --enable-shared --disable-static
	$(MAKE) -C $(B)/libburn-host-build -j$(JOBS)
	$(MAKE) -C $(B)/libburn-host-build install
	test -f $(GRUB_HOST_LIBBURN_INST)/usr/lib/pkgconfig/libburn-1.pc
	@touch $@

$(STAMP)/libisofs.host.built: $(STAMP)/libisofs.unpacked $(STAMP)/libburn.host.built \
                              $(CURDIR)/mk/grub.mk $(CURDIR)/mk/sources.mk
	rm -rf $(B)/libisofs-host-build $(GRUB_HOST_LIBISOFS_INST)
	mkdir -p $(B)/libisofs-host-build
	cd $(B)/libisofs-host-build && \
	  PKG_CONFIG_PATH="$(GRUB_HOST_PKGCONFIG)" \
	  CC="$(GRUB_BUILD_CC)" CFLAGS="-O2" \
	  $(LIBISOFS_SRC)/configure \
	    --prefix=$(abspath $(GRUB_HOST_LIBISOFS_INST))/usr \
	    --libdir=$(abspath $(GRUB_HOST_LIBISOFS_INST))/usr/lib \
	    --enable-shared --disable-static --disable-libacl --disable-zlib
	$(MAKE) -C $(B)/libisofs-host-build -j$(JOBS)
	$(MAKE) -C $(B)/libisofs-host-build install
	test -f $(GRUB_HOST_LIBISOFS_INST)/usr/lib/pkgconfig/libisofs-1.pc
	@touch $@

$(STAMP)/libisoburn.host.built: $(STAMP)/libisoburn.unpacked \
                                $(STAMP)/libburn.host.built $(STAMP)/libisofs.host.built \
                                $(CURDIR)/mk/grub.mk $(CURDIR)/mk/sources.mk
	rm -rf $(B)/libisoburn-host-build $(GRUB_HOST_LIBISOBURN_INST)
	mkdir -p $(B)/libisoburn-host-build
	cd $(B)/libisoburn-host-build && \
	  PKG_CONFIG_PATH="$(GRUB_HOST_PKGCONFIG):$(GRUB_HOST_LIBISOBURN_INST)/usr/lib/pkgconfig" \
	  CPPFLAGS="-I$(abspath $(GRUB_HOST_LIBBURN_INST))/usr/include \
	           -I$(abspath $(GRUB_HOST_LIBISOFS_INST))/usr/include" \
	  LDFLAGS="-L$(abspath $(GRUB_HOST_LIBBURN_INST))/usr/lib \
	           -L$(abspath $(GRUB_HOST_LIBISOFS_INST))/usr/lib" \
	  CC="$(GRUB_BUILD_CC)" CFLAGS="-O2" \
	  $(LIBISOBURN_SRC)/configure \
	    --prefix=$(abspath $(GRUB_HOST_LIBISOBURN_INST))/usr \
	    --libdir=$(abspath $(GRUB_HOST_LIBISOBURN_INST))/usr/lib \
	    --enable-shared --disable-static \
	    --disable-libreadline --disable-libacl --disable-zlib
	$(MAKE) -C $(B)/libisoburn-host-build -j$(JOBS)
	$(MAKE) -C $(B)/libisoburn-host-build install
	test -x $(GRUB_HOST_LIBISOBURN_INST)/usr/bin/xorriso
	@touch $@

# LLD's image base leaves raw PC images offset from their load addresses.
# The LZMA decompressor also needs no stripped linker sections before its
# end marker, since GRUB appends the compressed stream at that exact boundary.
# Pin the kernel and decompressor text to the addresses GRUB expects.
$(STAMP)/grub.host.pc.built: $(STAMP)/grub.unpacked $(STAMP)/libisoburn.host.built \
                             $(STAMP)/llvm.built $(CURDIR)/mk/grub.mk $(CURDIR)/mk/sources.mk
	rm -rf $(B)/grub-host-pc-build $(GRUB_HOST_INST)
	mkdir -p $(B)/grub-host-pc-build
	cd $(B)/grub-host-pc-build && \
	  BUILD_CC="$(GRUB_BUILD_CC)" \
	  HOST_CC="$(GRUB_BUILD_CC)" \
	  CC="$(GRUB_BUILD_CC)" \
	  TARGET_CC="$(GRUB_FW_PC_CC)" \
	  TARGET_LDFLAGS="$(GRUB_FW_LDFLAGS)" \
	  TARGET_OBJCOPY="$(GRUB_FW_TOOLS)/llvm-objcopy" \
	  TARGET_STRIP="$(GRUB_FW_TOOLS)/llvm-strip" \
	  TARGET_NM="$(GRUB_FW_TOOLS)/llvm-nm" \
	  TARGET_RANLIB="$(GRUB_FW_TOOLS)/llvm-ranlib" \
	  TARGET_CFLAGS="-O2 -ffreestanding -fno-stack-protector" \
	  $(GRUB_SRC)/configure \
	    --build=$(GRUB_BUILD_TRIPLET) --host=$(GRUB_BUILD_TRIPLET) \
	    --target=i386-linux-musl --with-platform=pc \
	    --prefix=$(GRUB_HOST_PREFIX) \
	    --disable-nls --disable-device-mapper --disable-grub-mkfont \
	    --disable-efiemu --disable-werror
	$(MAKE) -C $(B)/grub-host-pc-build/grub-core/lib/gnulib getopt-cdefs.h
	$(MAKE) -C $(B)/grub-host-pc-build \
	  'kernel_exec_LDFLAGS=$$(AM_LDFLAGS) $$(LDFLAGS_KERNEL) $$(TARGET_IMG_LDFLAGS) $$(TARGET_IMG_BASE_LDOPT),0x9000 -Wl,-Ttext,0x9000' \
	  'lzma_decompress_image_LDFLAGS=$$(AM_LDFLAGS) $$(LDFLAGS_IMAGE) $$(TARGET_IMG_LDFLAGS) $$(TARGET_IMG_BASE_LDOPT),0x8200 -Wl,-Ttext,0x8200 -Wl,--no-dynamic-linker -Wl,--build-id=none' \
	  -j$(JOBS)
	$(MAKE) -C $(B)/grub-host-pc-build install
	cp $(GRUB_HOST_PREFIX)/share/grub/themes/starfield/dejavu_14.pf2 \
	  $(GRUB_HOST_PREFIX)/share/grub/unicode.pf2
	test -x $(GRUB_HOST_PREFIX)/bin/grub-mkrescue
	test -d $(GRUB_HOST_PREFIX)/lib/grub/i386-pc
	test -f $(GRUB_HOST_PREFIX)/share/grub/unicode.pf2
	@touch $@

$(STAMP)/grub.host.efi.built: $(STAMP)/grub.host.pc.built $(CURDIR)/mk/grub.mk
	rm -rf $(B)/grub-host-efi-build $(GRUB_HOST_EFI_INST)
	mkdir -p $(B)/grub-host-efi-build
	cd $(B)/grub-host-efi-build && \
	  BUILD_CC="$(GRUB_BUILD_CC)" \
	  HOST_CC="$(GRUB_BUILD_CC)" \
	  CC="$(GRUB_BUILD_CC)" \
	  TARGET_CC="$(GRUB_FW_EFI_CC)" \
	  TARGET_LDFLAGS="$(GRUB_FW_LDFLAGS)" \
	  TARGET_OBJCOPY="$(GRUB_FW_TOOLS)/llvm-objcopy" \
	  TARGET_STRIP="$(GRUB_FW_TOOLS)/llvm-strip" \
	  TARGET_NM="$(GRUB_FW_TOOLS)/llvm-nm" \
	  TARGET_RANLIB="$(GRUB_FW_TOOLS)/llvm-ranlib" \
	  TARGET_CFLAGS="-O2 -ffreestanding -fno-stack-protector" \
	  $(GRUB_SRC)/configure \
	    --build=$(GRUB_BUILD_TRIPLET) --host=$(GRUB_BUILD_TRIPLET) \
	    --target=x86_64-linux-musl --with-platform=efi \
	    --prefix=/usr \
	    --disable-nls --disable-device-mapper --disable-grub-mkfont --disable-werror
	$(MAKE) -C $(B)/grub-host-efi-build/grub-core/lib/gnulib getopt-cdefs.h
	$(MAKE) -C $(B)/grub-host-efi-build -j$(JOBS)
	$(MAKE) -C $(B)/grub-host-efi-build DESTDIR=$(abspath $(GRUB_HOST_EFI_INST)) install
	test -d $(GRUB_HOST_EFI_INST)/usr/lib/grub/x86_64-efi
	cp -a $(GRUB_HOST_EFI_INST)/usr/lib/grub/x86_64-efi $(GRUB_HOST_PREFIX)/lib/grub/
	@touch $@

# Target xorriso and its libraries are installed before target GRUB tools.
$(STAMP)/libburn.target.built: $(STAMP)/libburn.unpacked $(STAMP)/musl.built \
                              $(STAMP)/llvm.built $(STAMP)/target.ccache \
                              $(CURDIR)/mk/grub.mk $(CURDIR)/mk/sources.mk
	rm -rf $(B)/libburn-target-build $(GRUB_TARGET_LIBBURN_INST)
	mkdir -p $(B)/libburn-target-build
	cd $(B)/libburn-target-build && \
	  CC="$(GRUB_TARGET_CC)" CFLAGS="$(GRUB_TARGET_CFLAGS)" \
	  CPPFLAGS="$(GRUB_TARGET_CPPFLAGS)" \
	  LDFLAGS="$(GRUB_TARGET_LDFLAGS)" \
	  AR="$(GRUB_FW_TOOLS)/llvm-ar" RANLIB="$(GRUB_FW_TOOLS)/llvm-ranlib" \
	  $(LIBBURN_SRC)/configure --build=$(GRUB_BUILD_TRIPLET) --host=$(TARGET) \
	    --prefix=/usr --libdir=/usr/lib --enable-shared --disable-static
	$(MAKE) -C $(B)/libburn-target-build -j$(JOBS)
	$(MAKE) -C $(B)/libburn-target-build DESTDIR=$(abspath $(GRUB_TARGET_LIBBURN_INST)) install
	test -f $(GRUB_TARGET_LIBBURN_INST)/usr/lib/pkgconfig/libburn-1.pc
	@touch $@

$(STAMP)/libisofs.target.built: $(STAMP)/libisofs.unpacked $(STAMP)/libburn.target.built \
                               $(STAMP)/musl.built $(STAMP)/llvm.built $(STAMP)/target.ccache \
                               $(CURDIR)/mk/grub.mk $(CURDIR)/mk/sources.mk
	rm -rf $(B)/libisofs-target-build
	mkdir -p $(B)/libisofs-target-build
	cd $(B)/libisofs-target-build && \
	  PKG_CONFIG_LIBDIR="$(GRUB_TARGET_PKGCONFIG)" PKG_CONFIG_PATH= \
	  PKG_CONFIG_SYSROOT_DIR="$(abspath $(GRUB_TARGET_STACK_INST))" \
	  CC="$(GRUB_TARGET_CC)" CFLAGS="$(GRUB_TARGET_CFLAGS)" \
	  CPPFLAGS="$(GRUB_TARGET_CPPFLAGS)" \
	  LDFLAGS="$(GRUB_TARGET_LDFLAGS)" \
	  AR="$(GRUB_FW_TOOLS)/llvm-ar" RANLIB="$(GRUB_FW_TOOLS)/llvm-ranlib" \
	  $(LIBISOFS_SRC)/configure --build=$(GRUB_BUILD_TRIPLET) --host=$(TARGET) \
	    --prefix=/usr --libdir=/usr/lib \
	    --enable-shared --disable-static --disable-libacl --disable-zlib
	$(MAKE) -C $(B)/libisofs-target-build -j$(JOBS)
	$(MAKE) -C $(B)/libisofs-target-build DESTDIR=$(abspath $(GRUB_TARGET_LIBISOFS_INST)) install
	test -f $(GRUB_TARGET_LIBISOFS_INST)/usr/lib/pkgconfig/libisofs-1.pc
	@touch $@

$(STAMP)/libisoburn.target.built: $(STAMP)/libisoburn.unpacked \
                                 $(STAMP)/libburn.target.built $(STAMP)/libisofs.target.built \
                                 $(STAMP)/musl.built $(STAMP)/llvm.built $(STAMP)/target.ccache \
                                 $(CURDIR)/mk/grub.mk $(CURDIR)/mk/sources.mk
	rm -rf $(B)/libisoburn-target-build
	mkdir -p $(B)/libisoburn-target-build
	cd $(B)/libisoburn-target-build && \
	  PKG_CONFIG_LIBDIR="$(GRUB_TARGET_PKGCONFIG)" PKG_CONFIG_PATH= \
	  PKG_CONFIG_SYSROOT_DIR="$(abspath $(GRUB_TARGET_STACK_INST))" \
	  CC="$(GRUB_TARGET_CC)" CFLAGS="$(GRUB_TARGET_CFLAGS)" \
	  CPPFLAGS="$(GRUB_TARGET_CPPFLAGS)" \
	  LDFLAGS="-L$(abspath $(GRUB_TARGET_STACK_INST))/usr/lib $(GRUB_TARGET_LDFLAGS)" \
	  AR="$(GRUB_FW_TOOLS)/llvm-ar" RANLIB="$(GRUB_FW_TOOLS)/llvm-ranlib" \
	  $(LIBISOBURN_SRC)/configure --build=$(GRUB_BUILD_TRIPLET) --host=$(TARGET) \
	    --prefix=/usr --libdir=/usr/lib \
	    --enable-shared --disable-static \
	    --disable-libreadline --disable-libacl --disable-zlib
	$(MAKE) -C $(B)/libisoburn-target-build -j$(JOBS)
	$(MAKE) -C $(B)/libisoburn-target-build DESTDIR=$(abspath $(GRUB_TARGET_LIBISOBURN_INST)) install
	test -x $(GRUB_TARGET_LIBISOBURN_INST)/usr/bin/xorriso
	@touch $@

$(STAMP)/xorriso.target.rootfs: $(STAMP)/libisoburn.target.built $(STAMP)/rootfs.done \
                                $(CURDIR)/mk/grub.mk
	mkdir -p $(ROOTFS)/usr
	cp -a $(GRUB_TARGET_STACK_INST)/usr/. $(ROOTFS)/usr/
	@touch $@

# GRUB utility binaries run on musl; firmware code is built for the selected platform.
$(STAMP)/grub.target.pc.built: $(STAMP)/grub.unpacked \
                               $(STAMP)/musl.built $(STAMP)/llvm.built $(STAMP)/target.ccache \
                               $(CURDIR)/mk/grub.mk $(CURDIR)/mk/sources.mk
	rm -rf $(B)/grub-target-pc-build $(GRUB_TARGET_INST)
	mkdir -p $(B)/grub-target-pc-build
	cd $(B)/grub-target-pc-build && \
	  BUILD_CC="$(GRUB_BUILD_CC)" \
	  HOST_CC="$(GRUB_TARGET_CC)" CC="$(GRUB_TARGET_CC)" \
	  PKG_CONFIG_LIBDIR="$(GRUB_TARGET_PKGCONFIG)" PKG_CONFIG_PATH= \
	  PKG_CONFIG_SYSROOT_DIR="$(abspath $(GRUB_TARGET_STACK_INST))" \
	  HOST_CFLAGS="$(GRUB_TARGET_CFLAGS)" \
	  HOST_CPPFLAGS="$(GRUB_TARGET_CPPFLAGS)" \
	  HOST_LDFLAGS="$(GRUB_TARGET_LDFLAGS)" \
	  LDFLAGS="$(GRUB_TARGET_LDFLAGS)" \
	  TARGET_CC="$(GRUB_FW_PC_CC)" \
	  TARGET_LDFLAGS="$(GRUB_FW_LDFLAGS)" \
	  TARGET_OBJCOPY="$(GRUB_FW_TOOLS)/llvm-objcopy" \
	  TARGET_STRIP="$(GRUB_FW_TOOLS)/llvm-strip" \
	  TARGET_NM="$(GRUB_FW_TOOLS)/llvm-nm" \
	  TARGET_RANLIB="$(GRUB_FW_TOOLS)/llvm-ranlib" \
	  TARGET_CFLAGS="-O2 -ffreestanding -fno-stack-protector" \
	  $(GRUB_SRC)/configure \
	    --build=$(GRUB_BUILD_TRIPLET) --host=$(TARGET) \
	    --target=i386-linux-musl --with-platform=pc \
	    --prefix=/usr --libdir=/usr/lib \
	    --disable-nls --disable-device-mapper --disable-grub-mkfont \
	    --disable-efiemu --disable-werror
	$(MAKE) -C $(B)/grub-target-pc-build/grub-core/lib/gnulib getopt-cdefs.h
	$(MAKE) -C $(B)/grub-target-pc-build \
	  'kernel_exec_LDFLAGS=$$(AM_LDFLAGS) $$(LDFLAGS_KERNEL) $$(TARGET_IMG_LDFLAGS) $$(TARGET_IMG_BASE_LDOPT),0x9000 -Wl,-Ttext,0x9000' \
	  -j$(JOBS)
	$(MAKE) -C $(B)/grub-target-pc-build DESTDIR=$(abspath $(GRUB_TARGET_INST)) install
	test -d $(GRUB_TARGET_INST)/usr/lib/grub/i386-pc
	@touch $@

$(STAMP)/grub.target.efi.built: $(STAMP)/grub.target.pc.built $(CURDIR)/mk/grub.mk
	rm -rf $(B)/grub-target-efi-build $(GRUB_TARGET_EFI_INST)
	mkdir -p $(B)/grub-target-efi-build
	cd $(B)/grub-target-efi-build && \
	  BUILD_CC="$(GRUB_BUILD_CC)" \
	  HOST_CC="$(GRUB_TARGET_CC)" CC="$(GRUB_TARGET_CC)" \
	  PKG_CONFIG_LIBDIR="$(GRUB_TARGET_PKGCONFIG)" PKG_CONFIG_PATH= \
	  PKG_CONFIG_SYSROOT_DIR="$(abspath $(GRUB_TARGET_STACK_INST))" \
	  HOST_CFLAGS="$(GRUB_TARGET_CFLAGS)" \
	  HOST_CPPFLAGS="$(GRUB_TARGET_CPPFLAGS)" \
	  HOST_LDFLAGS="$(GRUB_TARGET_LDFLAGS)" \
	  LDFLAGS="$(GRUB_TARGET_LDFLAGS)" \
	  TARGET_CC="$(GRUB_FW_EFI_CC)" \
	  TARGET_LDFLAGS="$(GRUB_FW_LDFLAGS)" \
	  TARGET_OBJCOPY="$(GRUB_FW_TOOLS)/llvm-objcopy" \
	  TARGET_STRIP="$(GRUB_FW_TOOLS)/llvm-strip" \
	  TARGET_NM="$(GRUB_FW_TOOLS)/llvm-nm" \
	  TARGET_RANLIB="$(GRUB_FW_TOOLS)/llvm-ranlib" \
	  TARGET_CFLAGS="-O2 -ffreestanding -fno-stack-protector" \
	  $(GRUB_SRC)/configure \
	    --build=$(GRUB_BUILD_TRIPLET) --host=$(TARGET) \
	    --target=x86_64-linux-musl --with-platform=efi \
	    --prefix=/usr --libdir=/usr/lib \
	    --disable-nls --disable-device-mapper --disable-grub-mkfont --disable-werror
	$(MAKE) -C $(B)/grub-target-efi-build/grub-core/lib/gnulib getopt-cdefs.h
	$(MAKE) -C $(B)/grub-target-efi-build -j$(JOBS)
	$(MAKE) -C $(B)/grub-target-efi-build DESTDIR=$(abspath $(GRUB_TARGET_EFI_INST)) install
	test -d $(GRUB_TARGET_EFI_INST)/usr/lib/grub/x86_64-efi
	cp -a $(GRUB_TARGET_EFI_INST)/usr/lib/grub/x86_64-efi \
	  $(GRUB_TARGET_INST)/usr/lib/grub/
	@touch $@

# Keep GRUB as the final target package staged by the Minimal image graph.
$(STAMP)/grub.rootfs: $(STAMP)/grub.target.efi.built $(STAMP)/xorriso.target.rootfs \
                      $(STAMP)/manpages.rootfs $(STAMP)/openssl.rootfs \
                      $(STAMP)/luks.rootfs $(STAMP)/make.rootfs $(STAMP)/llvm.rootfs \
                      $(STAMP)/m4.rootfs $(STAMP)/bison.rootfs \
                      $(STAMP)/flex.rootfs $(STAMP)/pkgconf.rootfs \
                      $(STAMP)/rootfs.done $(CURDIR)/mk/grub.mk
	mkdir -p $(ROOTFS)/usr
	cp -a $(GRUB_TARGET_INST)/usr/. $(ROOTFS)/usr/
	@touch $@
