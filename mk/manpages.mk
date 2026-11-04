# ---- Minimal-profile manual pages -----------------------------------------
MANDOC_INST  := $(B)/mandoc-install
MANPAGES_BUILD := $(B)/manpages
ZLIB_BUILD := $(B)/zlib-build
ZLIB_INST := $(B)/zlib-install
ZLIB_CC := $(CC_SYS_CACHED) -fuse-ld=lld -B$(abspath $(LLVM_INST))/usr/bin
ZLIB_LDFLAGS := -fuse-ld=lld -B$(abspath $(LLVM_INST))/usr/bin \
                -rtlib=compiler-rt -unwindlib=none
SPHINX_PYTHON ?= python3
SPHINX_VENV := $(B)/sphinx-venv

.PHONY: manpages
ifeq ($(PROFILE),minimal)
manpages: $(STAMP)/manpages.rootfs

$(STAMP)/zlib.built: $(STAMP)/zlib.unpacked $(STAMP)/musl.built $(STAMP)/llvm.built \
                     $(STAMP)/target.ccache $(CURDIR)/mk/manpages.mk $(CURDIR)/config.mk
	rm -rf $(ZLIB_BUILD) $(ZLIB_INST)
	mkdir -p $(ZLIB_BUILD)
	cp -a $(ZLIB_SRC)/. $(ZLIB_BUILD)/
	cd $(ZLIB_BUILD) && \
	  CHOST=$(TARGET) \
	  CC="$(ZLIB_CC)" \
	  AR="$(abspath $(LLVM_INST))/usr/bin/llvm-ar" \
	  RANLIB="$(abspath $(LLVM_INST))/usr/bin/llvm-ranlib" \
	  NM="$(abspath $(LLVM_INST))/usr/bin/llvm-nm" \
	  CFLAGS="-O2 -fno-stack-protector" \
	  LDFLAGS="$(ZLIB_LDFLAGS) -Wl,--undefined-version" \
	  ./configure --prefix=/usr --libdir=/usr/lib
	$(MAKE) -C $(ZLIB_BUILD) -j$(JOBS)
	$(MAKE) -C $(ZLIB_BUILD) DESTDIR=$(abspath $(ZLIB_INST)) install
	test -f $(ZLIB_INST)/usr/include/zlib.h
	test -e $(ZLIB_INST)/usr/lib/libz.so.1
	@touch $@

$(STAMP)/mandoc.built: $(STAMP)/mandoc.unpacked $(STAMP)/zlib.built \
                       $(STAMP)/musl.built $(STAMP)/llvm.built \
                       $(CURDIR)/mk/manpages.mk $(CURDIR)/config.mk
	rm -rf $(MANDOC_SRC)/configure.local $(MANDOC_INST)
	printf '%s\n' \
	  'CC="$(CC_SYS_CACHED) -fuse-ld=lld -B$(abspath $(LLVM_INST))/usr/bin"' \
	  'AR="$(abspath $(LLVM_INST))/usr/bin/llvm-ar"' \
	  'CFLAGS="-O2 -fno-stack-protector -I$(abspath $(ZLIB_INST))/usr/include"' \
	  'LDFLAGS="-L$(abspath $(ZLIB_INST))/usr/lib $(ZLIB_LDFLAGS)"' \
	  'PREFIX="/usr"' \
	  'BINDIR="/usr/bin"' \
	  'SBINDIR="/usr/sbin"' \
	  'MANDIR="/usr/share/man"' \
	  'MANPATH_DEFAULT="/usr/share/man"' \
	  'MANPATH_BASE="/usr/share/man"' \
	  > $(MANDOC_SRC)/configure.local
	cd $(MANDOC_SRC) && ./configure
	$(MAKE) -C $(MANDOC_SRC) -j$(JOBS)
	$(MAKE) -C $(MANDOC_SRC) DESTDIR=$(abspath $(MANDOC_INST)) install
	@touch $@

$(STAMP)/sphinx.built: $(CURDIR)/mk/manpages-requirements.txt $(CURDIR)/mk/manpages.mk
	rm -rf $(SPHINX_VENV)
	$(SPHINX_PYTHON) -m venv $(SPHINX_VENV)
	$(SPHINX_VENV)/bin/python -m pip install --disable-pip-version-check \
	  -r $(CURDIR)/mk/manpages-requirements.txt
	@touch $@

$(STAMP)/manpages.built: $(STAMP)/llvm.unpacked \
                         $(STAMP)/python.unpacked $(STAMP)/make.unpacked \
                         $(STAMP)/sphinx.built $(CURDIR)/mk/manpages.mk \
                         $(CURDIR)/config.mk
	rm -rf $(MANPAGES_BUILD)
	mkdir -p $(MANPAGES_BUILD)/llvm $(MANPAGES_BUILD)/clang
	$(SPHINX_VENV)/bin/python -m sphinx -q -b man -c $(LLVM_SRC)/llvm/docs \
	  $(LLVM_SRC)/llvm/docs $(MANPAGES_BUILD)/llvm
	$(SPHINX_VENV)/bin/python -m sphinx -q -b man -c $(LLVM_SRC)/clang/docs \
	  $(LLVM_SRC)/clang/docs $(MANPAGES_BUILD)/clang
	@touch $@

$(STAMP)/manpages.rootfs: $(STAMP)/mandoc.built $(STAMP)/manpages.built \
                          $(STAMP)/llvm.rootfs $(STAMP)/python.rootfs $(STAMP)/make.built \
                          $(STAMP)/rootfs.done $(CURDIR)/mk/manpages.mk
	mkdir -p $(ROOTFS)/usr
	cp -a $(ZLIB_INST)/usr/. $(ROOTFS)/usr/
	cp -a $(MANDOC_INST)/usr/. $(ROOTFS)/usr/
	mkdir -p $(ROOTFS)/usr/share/man/man1
	rm -f $(ROOTFS)/usr/share/man/man1/thelinuxkernel.1
	cp $(PYTHON_SRC)/Misc/python.man \
	  $(ROOTFS)/usr/share/man/man1/python$(PYTHON_VERSION).1
	ln -sf python$(PYTHON_VERSION).1 $(ROOTFS)/usr/share/man/man1/python3.1
	ln -sf python$(PYTHON_VERSION).1 $(ROOTFS)/usr/share/man/man1/python.1
	cp $(MAKE_INST)/usr/share/man/man1/make.1 $(ROOTFS)/usr/share/man/man1/
	for page in $(MANPAGES_BUILD)/llvm/*.1 $(MANPAGES_BUILD)/clang/*.1; do \
	  [ -f "$$page" ] || continue; \
	  name=$$(basename "$$page" .1); \
	  if [ -e "$(LLVM_INST)/usr/bin/$$name" ]; then \
	    cp "$$page" $(ROOTFS)/usr/share/man/man1/; \
	  fi; \
	done
	@touch $@
endif
