# ---- musl ------------------------------------------------------------------
$(STAMP)/musl.built: $(STAMP)/musl.unpacked $(STAMP)/headers.built $(STAMP)/target.ccache $(CURDIR)/mk/userland.mk $(CURDIR)/config.mk
	cd $(MUSL_SRC) && \
	  CC="$(strip $(if $(filter ON,$(TARGET_CCACHE)),$(CCACHE)) $(CLANG) --target=$(TARGET))" \
	  ./configure --prefix=/usr && \
	  $(MAKE) -j$(JOBS) && \
	  $(MAKE) DESTDIR=$(SYSROOT) install
	@touch $@

# ---- Ark (dynamic, musl) ---------------------------------------------------
ARK_CFLAGS := -std=c99 -Wall -Wextra -pedantic
ARK_BIN    := $(B)/ark-musl
CC_WRAP    := $(B)/cc-sys

# Single-executable wrapper so scripts that quote "$CC" work.
$(CC_WRAP): $(CURDIR)/mk/userland.mk $(STAMP)/llvm.built $(STAMP)/target.ccache
	mkdir -p $(B)
	printf '#!/bin/sh\nexec %s -fuse-ld=lld -B%s/usr/bin -Qunused-arguments "$$@"\n' \
	  '$(CC_SYS_CACHED)' '$(abspath $(LLVM_INST))' > $@
	chmod +x $@

$(STAMP)/ark.built: $(STAMP)/ark.unpacked $(STAMP)/musl.built $(STAMP)/llvm.built $(STAMP)/target.ccache $(CC_WRAP) $(CURDIR)/mk/userland.mk $(CURDIR)/config.mk
	cd $(ARK_SRC) && \
	  CC="$(CC_WRAP)" CFLAGS="$(ARK_CFLAGS)" ./build.sh build
	cp $(ARK_SRC)/build/ark $(ARK_BIN)
	@touch $@
