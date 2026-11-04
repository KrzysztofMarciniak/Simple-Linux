# NOTE: Perl currently fails to build, so it is excluded from `make minimal`.
# ---- Perl (cross-built for musl; excluded from Minimal) -----------------
PERL_BUILD := $(B)/perl-build
PERL_INST  := $(B)/perl-install
PERL_TOOL_BIN := $(abspath $(LLVM_INST))/usr/bin
PERL_TOOL_LIB := $(abspath $(LLVM_INST))/usr/lib$(if $(strip $(LD_LIBRARY_PATH)),:$(LD_LIBRARY_PATH))
PERL_HOST_CC ?= $(shell command -v gcc || command -v cc)

.PHONY: perl
ifeq ($(PROFILE),minimal)
perl: $(STAMP)/perl.rootfs

$(STAMP)/perl.built: $(STAMP)/perl.unpacked $(STAMP)/perl-cross.unpacked \
                     $(STAMP)/musl.built $(STAMP)/llvm.built $(STAMP)/target.ccache \
                     $(CC_WRAP) $(CURDIR)/mk/perl.mk \
                     $(CURDIR)/mk/patches/perl-my-chsize-assert.patch \
                     $(CURDIR)/config.mk
	rm -rf $(PERL_BUILD) $(PERL_INST)
	mkdir -p $(PERL_BUILD)
	cp -a $(PERL_SRC)/. $(PERL_BUILD)/
	cp -a $(PERL_CROSS_SRC)/. $(PERL_BUILD)/
	patch -p1 -d $(PERL_BUILD) < $(CURDIR)/mk/patches/perl-my-chsize-assert.patch
	ln -sf llvm-readobj $(PERL_TOOL_BIN)/readelf
	# Both compilers support C99 inline; perl-cross's generic defaults disable it.
	grep -q "^define d_static_inline 'undef'$$" $(PERL_BUILD)/cnf/configure_misc.sh && \
	  grep -q "^define perl_static_inline 'static'$$" $(PERL_BUILD)/cnf/configure_misc.sh && \
	  sed -i \
	    -e "s/^define d_static_inline 'undef'$$/define d_static_inline 'define'/" \
	    -e "s/^define perl_static_inline 'static'$$/define perl_static_inline 'static __inline__'/" \
	    $(PERL_BUILD)/cnf/configure_misc.sh && \
	  grep -q "^define d_static_inline 'define'$$" $(PERL_BUILD)/cnf/configure_misc.sh && \
	  grep -q "^define perl_static_inline 'static __inline__'$$" $(PERL_BUILD)/cnf/configure_misc.sh
	cd $(PERL_BUILD) && \
	  CC="$(CC_WRAP)" \
	  PATH="$(PERL_TOOL_BIN):$$PATH" \
	  LD_LIBRARY_PATH="$(PERL_TOOL_LIB)" \
	  NM="$(PERL_TOOL_BIN)/llvm-nm" \
	  READELF="$(PERL_TOOL_BIN)/readelf" \
	  OBJDUMP="$(PERL_TOOL_BIN)/llvm-objdump" \
	  ./configure \
	    --target=$(TARGET) \
	    --sysroot=$(abspath $(SYSROOT)) \
	    --prefix=/usr \
	    --man1dir=/usr/share/man/man1 \
	    --man3dir=/usr/share/man/man3 \
	    --ar="$(abspath $(LLVM_INST))/usr/bin/llvm-ar" \
	    --ranlib="$(abspath $(LLVM_INST))/usr/bin/llvm-ranlib" \
	    --host-cc="$(PERL_HOST_CC)"
	$(MAKE) -C $(PERL_BUILD) -j$(JOBS)
	$(MAKE) -C $(PERL_BUILD) DESTDIR=$(abspath $(PERL_INST)) install
	test -x $(PERL_INST)/usr/bin/perl
	test -f $(PERL_INST)/usr/share/man/man1/perl.1
	test -d $(PERL_INST)/usr/lib
	@touch $@

$(STAMP)/perl.rootfs: $(STAMP)/perl.built $(STAMP)/rootfs.done \
                      $(CURDIR)/mk/perl.mk
	mkdir -p $(ROOTFS)/usr
	cp -a $(PERL_INST)/usr/. $(ROOTFS)/usr/
	@touch $@
endif
