# ---- CPython (cross-built for musl; installed in Minimal) -----------------
PYTHON_HOST_BUILD := $(B)/python-host-build
PYTHON_BUILD      := $(B)/python-build
PYTHON_INST       := $(B)/python-install
PYTHON_HOST_ENV   := env -u CFLAGS -u CXXFLAGS -u CPPFLAGS -u LDFLAGS \
                     -u CMAKE_PREFIX_PATH -u CMAKE_GENERATOR
PYTHON_TARGET_LDFLAGS := -fuse-ld=lld -B$(abspath $(LLVM_INST))/usr/bin \
                         -rtlib=compiler-rt -unwindlib=none

.PHONY: python
ifeq ($(PROFILE),minimal)
python: $(STAMP)/python.rootfs
endif

# CPython requires a build interpreter matching its source's major.minor
# version. Build one natively for build-time generators; it is never installed.
$(STAMP)/python.host.built: $(STAMP)/python.unpacked $(CURDIR)/mk/python.mk $(CURDIR)/config.mk
	rm -rf $(PYTHON_HOST_BUILD)
	mkdir -p $(PYTHON_HOST_BUILD)
	cd $(PYTHON_HOST_BUILD) && $(PYTHON_HOST_ENV) \
	  CC=cc CXX=c++ $(PYTHON_SRC)/configure \
	    --prefix=/usr \
	    --without-ensurepip \
	    --disable-test-modules
	$(MAKE) -C $(PYTHON_HOST_BUILD) -j$(JOBS) python
	@touch $@

$(STAMP)/python.built: $(STAMP)/python.host.built $(STAMP)/musl.built $(STAMP)/llvm.built \
                       $(CURDIR)/mk/python.mk $(CURDIR)/mk/python-config.site $(CURDIR)/config.mk
	rm -rf $(PYTHON_BUILD) $(PYTHON_INST)
	mkdir -p $(PYTHON_BUILD)
	cd $(PYTHON_BUILD) && $(PYTHON_HOST_ENV) \
	  PATH="$(abspath $(LLVM_INST))/usr/bin:$$PATH" \
	  CONFIG_SITE=$(abspath $(CURDIR)/mk/python-config.site) \
	  CC="$(CC_SYS_CACHED)" \
	  AR="$(abspath $(LLVM_INST))/usr/bin/llvm-ar" \
	  RANLIB="$(abspath $(LLVM_INST))/usr/bin/llvm-ranlib" \
	  LDFLAGS="$(PYTHON_TARGET_LDFLAGS)" \
	  PKG_CONFIG_LIBDIR="$(abspath $(SYSROOT))/usr/lib/pkgconfig:$(abspath $(SYSROOT))/usr/share/pkgconfig" \
	  PKG_CONFIG_PATH= PKG_CONFIG_SYSROOT_DIR="$(abspath $(SYSROOT))" \
	  $(PYTHON_SRC)/configure \
	    --build=$$($(PYTHON_SRC)/config.guess) \
	    --host=$(TARGET) \
	    --prefix=/usr \
	    --with-build-python=$(abspath $(PYTHON_HOST_BUILD))/python \
	    --with-pkg-config=no \
	    --without-ensurepip \
	    --disable-test-modules
	$(MAKE) -C $(PYTHON_BUILD) -j$(JOBS)
	$(MAKE) -C $(PYTHON_BUILD) DESTDIR=$(abspath $(PYTHON_INST)) install
	rm -rf $(PYTHON_INST)/usr/include \
	       $(PYTHON_INST)/usr/lib/libpython*.a \
	       $(PYTHON_INST)/usr/lib/pkgconfig \
	       $(PYTHON_INST)/usr/lib/python$(PYTHON_VERSION)/config-*
	@touch $@

$(STAMP)/python.rootfs: $(STAMP)/python.built $(STAMP)/rootfs.done \
                        $(CURDIR)/mk/python.mk
	mkdir -p $(ROOTFS)/usr
	cp -a $(PYTHON_INST)/usr/. $(ROOTFS)/usr/
	@touch $@
