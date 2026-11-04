# ---- OpenSSL (target musl; installed in Minimal) ---------------------------
OPENSSL_INST := $(B)/openssl-install
OPENSSL_CC := $(CC_SYS_CACHED) -fuse-ld=lld -B$(abspath $(LLVM_INST))/usr/bin
OPENSSL_LDFLAGS := -fuse-ld=lld -B$(abspath $(LLVM_INST))/usr/bin \
                   -rtlib=compiler-rt -unwindlib=none

.PHONY: openssl
ifeq ($(PROFILE),minimal)
openssl: $(STAMP)/openssl.rootfs

$(STAMP)/openssl.built: $(STAMP)/openssl.unpacked $(STAMP)/musl.built $(STAMP)/llvm.built \
                        $(STAMP)/target.ccache $(CURDIR)/mk/openssl.mk
	rm -rf $(OPENSSL_SRC)/Makefile $(OPENSSL_SRC)/configdata.pm $(OPENSSL_INST)
	cd $(OPENSSL_SRC) && \
	  CC="$(OPENSSL_CC)" \
	  AR="$(abspath $(LLVM_INST))/usr/bin/llvm-ar" \
	  RANLIB="$(abspath $(LLVM_INST))/usr/bin/llvm-ranlib" \
	  NM="$(abspath $(LLVM_INST))/usr/bin/llvm-nm" \
	  LDFLAGS="$(OPENSSL_LDFLAGS)" \
	  ./Configure linux-x86_64 \
	    --prefix=/usr \
	    --openssldir=/etc/ssl \
	    --libdir=lib \
	    shared \
	    no-tests \
	    no-zlib
	$(MAKE) -C $(OPENSSL_SRC) -j$(JOBS)
	$(MAKE) -C $(OPENSSL_SRC) DESTDIR=$(abspath $(OPENSSL_INST)) install_sw install_ssldirs
	test -x $(OPENSSL_INST)/usr/bin/openssl
	test -e $(OPENSSL_INST)/usr/lib/libssl.so
	test -e $(OPENSSL_INST)/usr/lib/libcrypto.so
	test -d $(OPENSSL_INST)/usr/include/openssl
	@touch $@

$(STAMP)/openssl.rootfs: $(STAMP)/openssl.built $(STAMP)/rootfs.done \
                         $(CURDIR)/mk/openssl.mk
	cp -a $(OPENSSL_INST)/. $(ROOTFS)/
	@touch $@
endif
