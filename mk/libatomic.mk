# ---- libatomic (target atomic operations) ---------------------------------
LIBATOMIC_SRC := $(LLVM_SRC)/compiler-rt/lib/builtins
LIBATOMIC_DIR := $(LLVM_INST)/usr/lib

$(STAMP)/libatomic.built: $(STAMP)/llvm.built $(STAMP)/musl.built $(STAMP)/llvm.unpacked \
                          $(LIBATOMIC_SRC)/atomic.c $(LIBATOMIC_SRC)/assembly.h \
                          $(CURDIR)/mk/libatomic.mk
	mkdir -p $(LIBATOMIC_DIR)
	$(CC_SYS) -fPIC -shared -O2 -unwindlib=none \
	  -Wl,-soname,libatomic.so.1 \
	  -I$(LIBATOMIC_SRC) $(LIBATOMIC_SRC)/atomic.c \
	  -o $(LIBATOMIC_DIR)/libatomic.so.1
	ln -sf libatomic.so.1 $(LIBATOMIC_DIR)/libatomic.so
	@touch $@

$(STAMP)/llvm.rootfs: $(STAMP)/libatomic.built
