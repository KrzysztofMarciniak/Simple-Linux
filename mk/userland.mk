# ---- musl ------------------------------------------------------------------
$(STAMP)/musl.built: $(STAMP)/musl.unpacked $(STAMP)/headers.built
	cd $(MUSL_SRC) && \
	  CC="$(CLANG) --target=$(TARGET)" \
	  ./configure --prefix=/usr && \
	  $(MAKE) -j$(JOBS) && \
	  $(MAKE) DESTDIR=$(SYSROOT) install
	@touch $@

# ---- BusyBox (dynamic, musl; userland + init) ------------------------------
$(STAMP)/busybox.built: $(STAMP)/busybox.unpacked $(STAMP)/musl.built $(STAMP)/llvm.built $(CURDIR)/mk/userland.mk
	# empty stub so the clang driver's implicit -lssp_nonshared resolves
	$(abspath $(LLVM_INST))/usr/bin/llvm-ar rc $(abspath $(SYSROOT))/usr/lib/libssp_nonshared.a
	cd $(BUSYBOX_SRC) && \
	  $(MAKE) CC="$(CC_SYS)" HOSTCC=cc defconfig && \
	  sed -i \
	    -e 's/^.*CONFIG_STATIC[= ].*$$/# CONFIG_STATIC is not set/' \
	    -e 's/^CONFIG_STATIC_LIBGCC=y/# CONFIG_STATIC_LIBGCC is not set/' \
	    -e 's/^CONFIG_PIE=y/# CONFIG_PIE is not set/' \
	    -e 's/^.*CONFIG_TC[= ].*$$/CONFIG_TC=n/' \
	    -e 's/^.*CONFIG_USE_BB_CRYPT[= ].*$$/CONFIG_USE_BB_CRYPT=y/' \
	    -e 's/^.*CONFIG_USE_BB_CRYPT_SHA[= ].*$$/CONFIG_USE_BB_CRYPT_SHA=y/' \
	    -e 's/^.*CONFIG_USE_BB_CRYPT_YES[= ].*$$/CONFIG_USE_BB_CRYPT_YES=y/' \
	    -e 's/^.*CONFIG_CRYPTPW[= ].*$$/CONFIG_CRYPTPW=y/' \
	    -e 's/^.*CONFIG_MKPASSWD[= ].*$$/CONFIG_MKPASSWD=y/' \
	    -e 's/^.*CONFIG_KLOGD[= ].*$$/# CONFIG_KLOGD is not set/' \
	    -e 's/^.*CONFIG_SYSLOGD[= ].*$$/# CONFIG_SYSLOGD is not set/' \
	    -e 's/^.*CONFIG_LOGGER[= ].*$$/# CONFIG_LOGGER is not set/' \
	    -e 's/^.*CONFIG_LOGREAD[= ].*$$/# CONFIG_LOGREAD is not set/' \
	    -e 's|^CONFIG_EXTRA_CFLAGS=.*|CONFIG_EXTRA_CFLAGS="-fno-stack-protector"|' \
	    -e 's|^CONFIG_EXTRA_LDFLAGS=.*|CONFIG_EXTRA_LDFLAGS="-fuse-ld=lld -B$(abspath $(LLVM_INST))/usr/bin -no-pie -rtlib=compiler-rt -unwindlib=none"|' \
	    -e 's|^CONFIG_EXTRA_LDLIBS=.*|CONFIG_EXTRA_LDLIBS=""|' \
	    .config && \
	  yes "" | $(MAKE) CC="$(CC_SYS)" HOSTCC=cc oldconfig && \
	  $(MAKE) -j$(JOBS) CC="$(CC_SYS)" HOSTCC=cc && \
	  $(MAKE) CC="$(CC_SYS)" HOSTCC=cc CONFIG_PREFIX=$(ROOTFS) install
	mkdir -p $(ROOTFS)/lib
	cp -f $(SYSROOT)/usr/lib/libc.so $(ROOTFS)$(MUSL_LD)
	chmod 755 $(ROOTFS)$(MUSL_LD)
	@touch $@

# ---- Ark (dynamic, musl) ---------------------------------------------------
ARK_CFLAGS := -std=c99 -Wall -Wextra -pedantic
ARK_BIN    := $(B)/ark-musl
CC_WRAP    := $(B)/cc-sys

# Single-executable wrapper so scripts that quote "$CC" work.
$(CC_WRAP): $(CURDIR)/mk/userland.mk $(STAMP)/llvm.built
	mkdir -p $(B)
	printf '#!/bin/sh\nexec %s -fuse-ld=lld -B%s/usr/bin -Qunused-arguments "$$@"\n' \
	  '$(CC_SYS)' '$(abspath $(LLVM_INST))' > $@
	chmod +x $@

$(STAMP)/ark.built: $(STAMP)/ark.unpacked $(STAMP)/musl.built $(STAMP)/llvm.built $(CC_WRAP) $(CURDIR)/mk/userland.mk
	cd $(ARK_SRC) && \
	  CC="$(CC_WRAP)" CFLAGS="$(ARK_CFLAGS)" ./build.sh build
	cp $(ARK_SRC)/build/ark $(ARK_BIN)
	@touch $@
