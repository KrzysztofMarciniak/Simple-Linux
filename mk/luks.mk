# ---- LUKS tools and their target libraries (Minimal only) ----------------
LUKS_CC := $(CC_SYS_CACHED) -fuse-ld=lld -B$(abspath $(LLVM_INST))/usr/bin
LUKS_LDFLAGS := -fuse-ld=lld -B$(abspath $(LLVM_INST))/usr/bin \
                -rtlib=compiler-rt -unwindlib=none
LUKS_CXX := $(abspath $(LLVM_INST))/usr/bin/clang++ --target=$(TARGET) \
            --sysroot=$(abspath $(SYSROOT)) $(LUKS_LDFLAGS) -nostdlib++
LUKS_CMAKE_ARGS := -G "Unix Makefiles" \
                   -DCMAKE_SYSTEM_NAME=Linux \
                   -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
                   -DCMAKE_C_COMPILER=$(abspath $(LLVM_INST))/usr/bin/clang \
                   -DCMAKE_C_COMPILER_TARGET=$(TARGET) \
                   -DCMAKE_SYSROOT=$(abspath $(SYSROOT)) \
                   -DCMAKE_C_FLAGS="$(LUKS_LDFLAGS)" \
                   -DCMAKE_EXE_LINKER_FLAGS="$(LUKS_LDFLAGS)" \
                   -DCMAKE_SHARED_LINKER_FLAGS="$(LUKS_LDFLAGS)" \
                   -DCMAKE_FIND_ROOT_PATH=$(abspath $(SYSROOT)) \
                   -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
                   -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
                   -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
                   -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
                   -DCMAKE_INSTALL_PREFIX=/usr \
                   -DCMAKE_INSTALL_LIBDIR=lib \
                   -DCMAKE_BUILD_TYPE=Release

POPT_BUILD := $(B)/popt-build
POPT_INST := $(B)/popt-install
JSON_C_BUILD := $(B)/json-c-build
JSON_C_INST := $(B)/json-c-install
UTIL_LINUX_BUILD := $(B)/util-linux-build
UTIL_LINUX_INST := $(B)/util-linux-install
LVM2_BUILD := $(B)/lvm2-build
LVM2_INST := $(B)/lvm2-install
CRYPTSETUP_BUILD := $(B)/cryptsetup-build
CRYPTSETUP_INST := $(B)/cryptsetup-install
LUKS_SYSROOT := $(B)/luks-sysroot

.PHONY: luks
ifeq ($(PROFILE),minimal)
luks: $(STAMP)/luks.rootfs

$(STAMP)/popt.built: $(STAMP)/popt.unpacked $(STAMP)/musl.built $(STAMP)/llvm.built \
                     $(STAMP)/target.ccache $(CURDIR)/mk/luks.mk $(CURDIR)/config.mk
	rm -rf $(POPT_BUILD) $(POPT_INST)
	mkdir -p $(POPT_BUILD)
	cd $(POPT_BUILD) && \
	  CC="$(LUKS_CC)" \
	  AR="$(abspath $(LLVM_INST))/usr/bin/llvm-ar" \
	  RANLIB="$(abspath $(LLVM_INST))/usr/bin/llvm-ranlib" \
	  LDFLAGS="$(LUKS_LDFLAGS)" \
	  $(POPT_SRC)/configure \
	    --host=$(TARGET) \
	    --prefix=/usr \
	    --libdir=/usr/lib \
	    --disable-nls \
	    --disable-static \
	    --enable-shared \
	    --disable-rpath
	$(MAKE) -C $(POPT_BUILD) -j$(JOBS)
	$(MAKE) -C $(POPT_BUILD) DESTDIR=$(abspath $(POPT_INST)) install
	test -e $(POPT_INST)/usr/lib/libpopt.so
	test -f $(POPT_INST)/usr/include/popt.h
	@touch $@

$(STAMP)/json-c.built: $(STAMP)/json-c.unpacked $(STAMP)/musl.built $(STAMP)/llvm.built \
                       $(STAMP)/target.ccache $(CURDIR)/mk/luks.mk $(CURDIR)/config.mk
	rm -rf $(JSON_C_BUILD) $(JSON_C_INST)
	cmake -S $(JSON_C_SRC) -B $(JSON_C_BUILD) $(LUKS_CMAKE_ARGS) \
	  -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF -DBUILD_TESTING=OFF \
	  -DDISABLE_WERROR=ON
	$(MAKE) -C $(JSON_C_BUILD) -j$(JOBS)
	$(MAKE) -C $(JSON_C_BUILD) DESTDIR=$(abspath $(JSON_C_INST)) install
	test -e $(JSON_C_INST)/usr/lib/libjson-c.so
	test -f $(JSON_C_INST)/usr/include/json-c/json.h
	@touch $@

$(STAMP)/util-linux.built: $(STAMP)/util-linux.unpacked $(STAMP)/musl.built $(STAMP)/llvm.built \
                           $(STAMP)/target.ccache $(CURDIR)/mk/luks.mk $(CURDIR)/config.mk
	rm -rf $(UTIL_LINUX_BUILD) $(UTIL_LINUX_INST)
	mkdir -p $(UTIL_LINUX_BUILD)
	cp -a $(UTIL_LINUX_SRC)/. $(UTIL_LINUX_BUILD)/
	cd $(UTIL_LINUX_BUILD) && \
	  CC="$(LUKS_CC)" \
	  CXX="$(LUKS_CXX)" \
	  AR="$(abspath $(LLVM_INST))/usr/bin/llvm-ar" \
	  RANLIB="$(abspath $(LLVM_INST))/usr/bin/llvm-ranlib" \
	  LDFLAGS="$(LUKS_LDFLAGS)" \
	  ./configure \
	    --host=$(TARGET) \
	    --prefix=/usr \
	    --libdir=/usr/lib \
	    --disable-all-programs \
	    --enable-libuuid \
	    --enable-libblkid \
	    --disable-asciidoc
	$(MAKE) -C $(UTIL_LINUX_BUILD) -j$(JOBS)
	$(MAKE) -C $(UTIL_LINUX_BUILD) DESTDIR=$(abspath $(UTIL_LINUX_INST)) install
	test -e $(UTIL_LINUX_INST)/usr/lib/libuuid.so
	test -e $(UTIL_LINUX_INST)/usr/lib/libblkid.so
	test -f $(UTIL_LINUX_INST)/usr/include/uuid/uuid.h
	@touch $@

$(STAMP)/lvm2-dm.built: $(STAMP)/lvm2.unpacked $(STAMP)/musl.built $(STAMP)/llvm.built \
                        $(STAMP)/target.ccache $(CURDIR)/mk/luks.mk $(CURDIR)/config.mk
	rm -rf $(LVM2_BUILD) $(LVM2_INST)
	mkdir -p $(LVM2_BUILD)
	cp -a $(LVM2_SRC)/. $(LVM2_BUILD)/
	cd $(LVM2_BUILD) && \
	  CC="$(LUKS_CC)" \
	  CXX="$(LUKS_CXX)" \
	  AR="$(abspath $(LLVM_INST))/usr/bin/llvm-ar" \
	  RANLIB="$(abspath $(LLVM_INST))/usr/bin/llvm-ranlib" \
	  LDFLAGS="$(LUKS_LDFLAGS)" \
	  ./configure \
	    --host=$(TARGET) \
	    --prefix=/usr \
	    --libdir=/usr/lib \
	    --disable-readline \
	    --disable-selinux \
	    --disable-udev_sync \
	    --disable-udev_rules \
	    --enable-pkgconfig
	$(MAKE) -C $(LVM2_BUILD) -j$(JOBS) device-mapper
	$(MAKE) -C $(LVM2_BUILD) DESTDIR=$(abspath $(LVM2_INST)) install_device-mapper
	test -e $(LVM2_INST)/usr/lib/libdevmapper.so
	@touch $@

$(STAMP)/luks-sysroot.built: $(STAMP)/popt.built $(STAMP)/json-c.built \
                             $(STAMP)/util-linux.built $(STAMP)/lvm2-dm.built \
                             $(STAMP)/openssl.built $(CURDIR)/mk/luks.mk
	rm -rf $(LUKS_SYSROOT)
	mkdir -p $(LUKS_SYSROOT)
	for root in $(POPT_INST) $(JSON_C_INST) $(UTIL_LINUX_INST) $(LVM2_INST) $(OPENSSL_INST); do \
	  cp -a "$$root"/. $(LUKS_SYSROOT)/ || exit; \
	done
	test -f $(LUKS_SYSROOT)/usr/lib/pkgconfig/popt.pc
	test -f $(LUKS_SYSROOT)/usr/lib/pkgconfig/json-c.pc
	test -f $(LUKS_SYSROOT)/usr/lib/pkgconfig/uuid.pc
	test -f $(LUKS_SYSROOT)/usr/lib/pkgconfig/devmapper.pc
	test -f $(LUKS_SYSROOT)/usr/lib/pkgconfig/libcrypto.pc
	@touch $@

$(STAMP)/cryptsetup.built: $(STAMP)/cryptsetup.unpacked $(STAMP)/luks-sysroot.built \
                           $(STAMP)/musl.built $(STAMP)/llvm.built \
                           $(STAMP)/target.ccache $(CURDIR)/mk/luks.mk $(CURDIR)/config.mk
	rm -rf $(CRYPTSETUP_BUILD) $(CRYPTSETUP_INST)
	mkdir -p $(CRYPTSETUP_BUILD)
	cp -a $(CRYPTSETUP_SRC)/. $(CRYPTSETUP_BUILD)/
	cd $(CRYPTSETUP_BUILD) && \
	  PKG_CONFIG_LIBDIR="$(abspath $(LUKS_SYSROOT))/usr/lib/pkgconfig:$(abspath $(LUKS_SYSROOT))/usr/share/pkgconfig" \
	  PKG_CONFIG_SYSROOT_DIR="$(abspath $(LUKS_SYSROOT))" \
	  PKG_CONFIG_PATH= \
	  CC="$(LUKS_CC)" \
	  CXX="$(LUKS_CXX)" \
	  AR="$(abspath $(LLVM_INST))/usr/bin/llvm-ar" \
	  RANLIB="$(abspath $(LLVM_INST))/usr/bin/llvm-ranlib" \
	  CPPFLAGS="-I$(abspath $(LUKS_SYSROOT))/usr/include" \
	  LDFLAGS="-L$(abspath $(LUKS_SYSROOT))/usr/lib $(LUKS_LDFLAGS)" \
	  ./configure \
	    --host=$(TARGET) \
	    --prefix=/usr \
	    --libdir=/usr/lib \
	    --with-crypto_backend=openssl \
	    --enable-internal-sse-argon2 \
	    --disable-asciidoc \
	    --disable-ssh-token \
	    --disable-udev \
	    --disable-veritysetup \
	    --disable-integritysetup
	$(MAKE) -C $(CRYPTSETUP_BUILD) -j$(JOBS)
	$(MAKE) -C $(CRYPTSETUP_BUILD) DESTDIR=$(abspath $(CRYPTSETUP_INST)) install
	test -x $(CRYPTSETUP_INST)/usr/sbin/cryptsetup
	test -e $(CRYPTSETUP_INST)/usr/lib/libcryptsetup.so
	test -f $(CRYPTSETUP_INST)/usr/share/man/man8/cryptsetup.8
	@touch $@

$(STAMP)/luks.rootfs: $(STAMP)/cryptsetup.built $(STAMP)/rootfs.done \
                      $(CURDIR)/mk/luks.mk
	mkdir -p $(ROOTFS)/usr
	for root in $(POPT_INST) $(JSON_C_INST) $(UTIL_LINUX_INST) $(LVM2_INST) $(CRYPTSETUP_INST); do \
	  cp -a "$$root"/usr/. $(ROOTFS)/usr/ || exit; \
	done
	@touch $@
endif
