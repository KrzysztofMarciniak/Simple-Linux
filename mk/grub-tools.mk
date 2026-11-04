# ---- GRUB rebuild tools for the Minimal target ----------------------------
GRUB_TOOLS_CFLAGS := -O2 -fno-stack-protector
GRUB_TOOLS_LDFLAGS := -fuse-ld=lld -B$(abspath $(LLVM_INST))/usr/bin \
                      -rtlib=compiler-rt -unwindlib=none

M4_BUILD := $(B)/m4-build
M4_INST := $(B)/m4-install
BISON_BUILD := $(B)/bison-build
BISON_INST := $(B)/bison-install
FLEX_BUILD := $(B)/flex-build
FLEX_INST := $(B)/flex-install
PKGCONF_BUILD := $(B)/pkgconf-build
PKGCONF_INST := $(B)/pkgconf-install

.PHONY: grub-tools
ifeq ($(PROFILE),minimal)
grub-tools: $(STAMP)/m4.rootfs $(STAMP)/bison.rootfs \
            $(STAMP)/flex.rootfs $(STAMP)/pkgconf.rootfs

$(STAMP)/m4.built: $(STAMP)/m4.unpacked $(STAMP)/musl.built $(STAMP)/llvm.built \
                   $(STAMP)/target.ccache $(CURDIR)/mk/grub-tools.mk $(CURDIR)/config.mk
	rm -rf $(M4_BUILD) $(M4_INST)
	mkdir -p $(M4_BUILD)
	cd $(M4_BUILD) && \
	  CC="$(CC_SYS_CACHED)" CFLAGS="$(GRUB_TOOLS_CFLAGS)" \
	  LDFLAGS="$(GRUB_TOOLS_LDFLAGS)" \
	  $(M4_SRC)/configure --build=$(GRUB_BUILD_TRIPLET) --host=$(TARGET) \
	    --prefix=/usr --disable-nls
	$(MAKE) -C $(M4_BUILD) -j$(JOBS)
	$(MAKE) -C $(M4_BUILD) DESTDIR=$(abspath $(M4_INST)) install
	test -x $(M4_INST)/usr/bin/m4
	@touch $@

$(STAMP)/m4.rootfs: $(STAMP)/m4.built $(STAMP)/rootfs.done $(CURDIR)/mk/grub-tools.mk
	mkdir -p $(ROOTFS)/usr
	cp -a $(M4_INST)/usr/. $(ROOTFS)/usr/
	@touch $@

$(STAMP)/bison.built: $(STAMP)/bison.unpacked $(STAMP)/m4.built \
                      $(STAMP)/musl.built $(STAMP)/llvm.built $(STAMP)/target.ccache \
                      $(CURDIR)/mk/grub-tools.mk $(CURDIR)/config.mk
	rm -rf $(BISON_BUILD) $(BISON_INST)
	mkdir -p $(BISON_BUILD)
	cd $(BISON_BUILD) && \
	  CC="$(CC_SYS_CACHED)" CFLAGS="$(GRUB_TOOLS_CFLAGS)" \
	  LDFLAGS="$(GRUB_TOOLS_LDFLAGS)" M4=/usr/bin/m4 \
	  YACC=bison \
	  $(BISON_SRC)/configure --build=$(GRUB_BUILD_TRIPLET) --host=$(TARGET) \
	    --prefix=/usr --disable-nls
	$(MAKE) -C $(BISON_BUILD) -j$(JOBS)
	$(MAKE) -C $(BISON_BUILD) DESTDIR=$(abspath $(BISON_INST)) install
	test -x $(BISON_INST)/usr/bin/bison
	test -d $(BISON_INST)/usr/share/bison
	@touch $@

$(STAMP)/bison.rootfs: $(STAMP)/bison.built $(STAMP)/m4.rootfs \
                       $(STAMP)/rootfs.done $(CURDIR)/mk/grub-tools.mk
	mkdir -p $(ROOTFS)/usr
	cp -a $(BISON_INST)/usr/. $(ROOTFS)/usr/
	@touch $@

$(STAMP)/flex.built: $(STAMP)/flex.unpacked $(STAMP)/bison.built $(STAMP)/m4.built \
                     $(STAMP)/musl.built $(STAMP)/llvm.built $(STAMP)/target.ccache \
                     $(CURDIR)/mk/grub-tools.mk $(CURDIR)/config.mk
	rm -rf $(FLEX_BUILD) $(FLEX_INST)
	mkdir -p $(FLEX_BUILD)
	cd $(FLEX_BUILD) && \
	  ac_cv_func_malloc_0_nonnull=yes \
	  ac_cv_func_realloc_0_nonnull=yes \
	  CC="$(CC_SYS_CACHED)" CFLAGS="$(GRUB_TOOLS_CFLAGS)" \
	  LDFLAGS="$(GRUB_TOOLS_LDFLAGS)" YACC=bison \
	  $(FLEX_SRC)/configure --build=$(GRUB_BUILD_TRIPLET) --host=$(TARGET) \
	    --prefix=/usr --disable-nls --disable-bootstrap
	$(MAKE) -C $(FLEX_BUILD) -j$(JOBS)
	$(MAKE) -C $(FLEX_BUILD) DESTDIR=$(abspath $(FLEX_INST)) install
	test -x $(FLEX_INST)/usr/bin/flex
	@touch $@

$(STAMP)/flex.rootfs: $(STAMP)/flex.built $(STAMP)/bison.rootfs \
                      $(STAMP)/rootfs.done $(CURDIR)/mk/grub-tools.mk
	mkdir -p $(ROOTFS)/usr
	cp -a $(FLEX_INST)/usr/. $(ROOTFS)/usr/
	@touch $@

$(STAMP)/pkgconf.built: $(STAMP)/pkgconf.unpacked $(STAMP)/musl.built \
                        $(STAMP)/llvm.built $(STAMP)/target.ccache \
                        $(CURDIR)/mk/grub-tools.mk $(CURDIR)/config.mk
	rm -rf $(PKGCONF_BUILD) $(PKGCONF_INST)
	mkdir -p $(PKGCONF_BUILD)
	cd $(PKGCONF_BUILD) && \
	  CC="$(CC_SYS_CACHED)" CFLAGS="$(GRUB_TOOLS_CFLAGS)" \
	  LDFLAGS="$(GRUB_TOOLS_LDFLAGS)" \
	  $(PKGCONF_SRC)/configure --build=$(GRUB_BUILD_TRIPLET) --host=$(TARGET) \
	    --prefix=/usr \
	    --with-pkg-config-dir=/usr/lib/pkgconfig:/usr/share/pkgconfig
	$(MAKE) -C $(PKGCONF_BUILD) -j$(JOBS)
	$(MAKE) -C $(PKGCONF_BUILD) DESTDIR=$(abspath $(PKGCONF_INST)) install
	ln -sf pkgconf $(PKGCONF_INST)/usr/bin/pkg-config
	test -x $(PKGCONF_INST)/usr/bin/pkgconf
	test -L $(PKGCONF_INST)/usr/bin/pkg-config
	@touch $@

$(STAMP)/pkgconf.rootfs: $(STAMP)/pkgconf.built $(STAMP)/rootfs.done \
                         $(CURDIR)/mk/grub-tools.mk
	mkdir -p $(ROOTFS)/usr
	cp -a $(PKGCONF_INST)/usr/. $(ROOTFS)/usr/
	@touch $@
endif
