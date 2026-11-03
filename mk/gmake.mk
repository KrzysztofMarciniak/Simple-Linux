# ---- GNU make (dynamic, musl) ----------------------------------------------
MAKE_BUILD := $(B)/make-build
MAKE_INST  := $(B)/make-install

.PHONY: gmake
gmake: $(STAMP)/make.rootfs

$(STAMP)/make.built: $(STAMP)/make.unpacked $(STAMP)/musl.built $(STAMP)/llvm.built $(STAMP)/target.ccache $(CC_WRAP) $(CURDIR)/mk/gmake.mk $(CURDIR)/config.mk
	rm -rf $(MAKE_BUILD) $(MAKE_INST)
	mkdir -p $(MAKE_BUILD)
	cd $(MAKE_BUILD) && env -u LDFLAGS -u CFLAGS -u CPPFLAGS \
	  CC="$(CC_SYS_CACHED)" \
	  LDFLAGS="-fuse-ld=lld -B$(abspath $(LLVM_INST))/usr/bin -no-pie -rtlib=compiler-rt -unwindlib=none" \
	  $(MAKE_SRC)/configure \
	    --host=$(TARGET) \
	    --prefix=/usr \
	    --disable-nls \
	    --disable-load \
	    --without-guile
	$(MAKE) -C $(MAKE_BUILD) -j$(JOBS)
	$(MAKE) -C $(MAKE_BUILD) DESTDIR=$(abspath $(MAKE_INST)) install-strip
	@touch $@

$(STAMP)/make.rootfs: $(STAMP)/make.built $(STAMP)/rootfs.done
	mkdir -p $(ROOTFS)/usr/bin
	rm -f $(ROOTFS)/bin/make $(ROOTFS)/usr/bin/make
	cp -a $(MAKE_INST)/usr/bin/make $(ROOTFS)/usr/bin/make
	@touch $@

$(INITRD): $(STAMP)/make.rootfs
