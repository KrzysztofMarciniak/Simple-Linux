# ---- musl ------------------------------------------------------------------
$(STAMP)/musl.built: $(STAMP)/musl.unpacked $(STAMP)/headers.built
	cd $(MUSL_SRC) && \
	  CC="$(CLANG) --target=$(TARGET)" ./configure --prefix=/usr --disable-shared && \
	  $(MAKE) -j$(JOBS) && $(MAKE) DESTDIR=$(SYSROOT) install
	@touch $@

# ---- BusyBox (userland + init) ---------------------------------------------
$(STAMP)/busybox.built: $(STAMP)/busybox.unpacked $(STAMP)/musl.built
	cd $(BUSYBOX_SRC) && \
	  $(MAKE) CC="$(CC_SYS)" HOSTCC=cc defconfig && \
	  sed -i -e 's/^.*CONFIG_STATIC[= ].*$$/CONFIG_STATIC=y/' \
	         -e 's/^.*CONFIG_TC[= ].*$$/CONFIG_TC=n/' .config && \
	  yes "" | $(MAKE) CC="$(CC_SYS)" HOSTCC=cc oldconfig && \
	  $(MAKE) -j$(JOBS) CC="$(CC_SYS)" HOSTCC=cc && \
	  $(MAKE) CC="$(CC_SYS)" HOSTCC=cc CONFIG_PREFIX=$(ROOTFS) install
	@touch $@

# ---- Ark -------------------------------------------------------------------
ARK_CFLAGS := -static -std=c99 -Wall -Wextra -pedantic
ARK_BIN := $(B)/ark-musl

$(STAMP)/ark.built: $(STAMP)/ark.unpacked $(CURDIR)/mk/userland.mk
	cd $(ARK_SRC) && \
	  CC="cc" CFLAGS="$(ARK_CFLAGS)" ./build.sh build
	cp $(ARK_SRC)/build/ark $(ARK_BIN)
	@touch $@
