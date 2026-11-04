# ---- LLVM seed toolchain (clang + lld) -------------------------------------
# Built with the host musl toolchain and installed into the rootfs (/usr).
include mk/llvm-runtime.mk

LLVM_BUILD := $(B)/llvm-build
LLVM_INST  := $(B)/llvm-install
LLVM_RUNTIME_LINK_FLAGS := -resource-dir=$(LLVM_RUNTIME_RESOURCE_DIR) -L$(LLVM_RUNTIME_LIBDIR) -Wl,-rpath-link,$(LLVM_RUNTIME_LIBDIR) -rtlib=compiler-rt -unwindlib=libunwind
LLVM_RUNTIME_LD_LIBRARY_PATH := $(LLVM_RUNTIME_LIBDIR)$(if $(strip $(LD_LIBRARY_PATH)),:$(LD_LIBRARY_PATH))
LLVM_BUILD_ENV := env -u CC -u CXX -u CFLAGS -u CXXFLAGS -u CPPFLAGS -u LDFLAGS \
                  -u CMAKE_PREFIX_PATH -u CMAKE_GENERATOR

.PHONY: toolchain
toolchain: $(STAMP)/llvm.built $(STAMP)/llvm.rootfs

$(STAMP)/llvm.config: FORCE
	@mkdir -p $(STAMP)
	@printf '%s\n' '$(LLVM_CCACHE_BUILD)' | cmp -s - $@ || printf '%s\n' '$(LLVM_CCACHE_BUILD)' > $@

# Keep libc++ headers/linking explicit; LLVM_ENABLE_LIBCXX injects -stdlib into
# compile flags, making this Clang's compile-only -fPIC check fail under -Werror.
$(STAMP)/llvm.built: $(STAMP)/llvm.unpacked $(STAMP)/llvm.runtime $(STAMP)/llvm.config $(CURDIR)/mk/toolchain.mk $(CURDIR)/config.mk
	rm -rf $(LLVM_BUILD) $(LLVM_INST)
	mkdir -p $(LLVM_INST)/usr
	cp -a $(LLVM_RUNTIME_INST)/usr/. $(LLVM_INST)/usr/
	$(LLVM_BUILD_ENV) \
	  cmake -S $(LLVM_SRC)/llvm -B $(LLVM_BUILD) \
	    -DCMAKE_BUILD_TYPE=Release \
	    -DCMAKE_INSTALL_PREFIX=/usr \
	    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
	    -DCMAKE_C_COMPILER=clang \
	    -DCMAKE_CXX_COMPILER=clang++ \
	    -DCMAKE_CXX_FLAGS='-nostdinc++ -isystem $(abspath $(LLVM_RUNTIME_INST))/usr/include/c++/v1' \
	    -DCMAKE_CXX_STANDARD_LIBRARIES='-stdlib=libc++' \
	    -DCMAKE_EXE_LINKER_FLAGS='$(LLVM_RUNTIME_LINK_FLAGS)' \
	    -DCMAKE_SHARED_LINKER_FLAGS='$(LLVM_RUNTIME_LINK_FLAGS)' \
	    -DCMAKE_MODULE_LINKER_FLAGS='$(LLVM_RUNTIME_LINK_FLAGS)' \
	    -DLLVM_ENABLE_ASSERTIONS=OFF \
	    -DLLVM_CCACHE_BUILD=$(LLVM_CCACHE_BUILD) \
	    -DLLVM_ENABLE_PROJECTS='clang;lld' \
	    -DLLVM_ENABLE_RUNTIMES=compiler-rt \
	    -DLLVM_ENABLE_LIBCXX=OFF \
	    -DCLANG_DEFAULT_RTLIB=compiler-rt \
	    -DCLANG_DEFAULT_CXX_STDLIB=libc++ \
	    -DCOMPILER_RT_BUILD_BUILTINS=ON \
	    -DCOMPILER_RT_BUILD_CRT=ON \
	    -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
	    -DLLVM_BUILD_STATIC=OFF \
	    -DLIBCLANG_BUILD_STATIC=OFF \
	    -DLLVM_STATIC_LINK_CXX_STDLIB=OFF \
	    -DLLVM_BUILD_LLVM_DYLIB=ON \
	    -DLLVM_LINK_LLVM_DYLIB=ON \
	    -DCLANG_LINK_CLANG_DYLIB=ON \
	    -DLLVM_TARGETS_TO_BUILD=X86 \
	    -DLLVM_DEFAULT_TARGET_TRIPLE=$(TARGET) \
	    -DCLANG_DEFAULT_LINKER=lld \
	    -DCLANG_DEFAULT_UNWINDLIB=libunwind \
	    -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
	    -DLLVM_INSTALL_BINUTILS_SYMLINKS=ON \
	    -DLLVM_INCLUDE_TESTS=OFF \
	    -DLLVM_INCLUDE_EXAMPLES=OFF \
	    -DLLVM_INCLUDE_BENCHMARKS=OFF \
	    -DLLVM_INCLUDE_DOCS=OFF \
	    -DLLVM_ENABLE_ZLIB=OFF \
	    -DLLVM_ENABLE_ZSTD=OFF \
	    -DLLVM_ENABLE_LIBXML2=OFF \
	    -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
	    -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
	    -DCOMPILER_RT_BUILD_XRAY=OFF \
	    -DCOMPILER_RT_BUILD_PROFILE=OFF \
	    -DCOMPILER_RT_BUILD_MEMPROF=OFF \
	    -DCOMPILER_RT_BUILD_ORC=OFF \
	    -DCOMPILER_RT_BUILD_GWP_ASAN=OFF \
	    -DCOMPILER_RT_BUILD_CTX_PROFILE=OFF \
	    -DCOMPILER_RT_INCLUDE_TESTS=OFF \
	    -DLLVM_ENABLE_TERMINFO=OFF

	$(LLVM_BUILD_ENV) env LD_LIBRARY_PATH='$(LLVM_RUNTIME_LD_LIBRARY_PATH)' \
	  cmake --build $(LLVM_BUILD) --parallel $(JOBS)
	$(LLVM_BUILD_ENV) DESTDIR=$(LLVM_INST) cmake --install $(LLVM_BUILD) --strip

	mkdir -p $(LLVM_INST)/usr/bin
	ln -sf clang $(LLVM_INST)/usr/bin/cc
	ln -sf clang++ $(LLVM_INST)/usr/bin/c++
	ln -sf ld.lld $(LLVM_INST)/usr/bin/ld
	ln -sf llvm-ar $(LLVM_INST)/usr/bin/ar
	ln -sf llvm-ranlib $(LLVM_INST)/usr/bin/ranlib
	ln -sf llvm-nm $(LLVM_INST)/usr/bin/nm
	ln -sf llvm-objcopy $(LLVM_INST)/usr/bin/objcopy
	ln -sf llvm-objdump $(LLVM_INST)/usr/bin/objdump
	ln -sf llvm-strip $(LLVM_INST)/usr/bin/strip
	ln -sf llvm-readelf $(LLVM_INST)/usr/bin/readelf
	ln -sf llvm-addr2line $(LLVM_INST)/usr/bin/addr2line

	@touch $@

# ---- Normal install into the rootfs: /usr/bin, /usr/lib, /usr/include ------
# BusyBox applets with the same names (ar, nm, strip, ...) are removed first,
# otherwise cp would write through the symlink and overwrite busybox itself.
# The musl headers and crt*.o/libc.so from the sysroot go to /usr as well, so
# clang finds them with no --sysroot and no config files.
.PHONY: llvm-rootfs
llvm-rootfs: $(STAMP)/llvm.rootfs

$(STAMP)/llvm.rootfs: $(STAMP)/llvm.built $(STAMP)/musl.built $(STAMP)/rootfs.done
	mkdir -p $(ROOTFS)/usr/bin $(ROOTFS)/usr/lib $(ROOTFS)/usr/include
	for f in $(LLVM_INST)/usr/bin/*; do \
	  n=$$(basename $$f); \
	  rm -f $(ROOTFS)/bin/$$n $(ROOTFS)/sbin/$$n $(ROOTFS)/usr/sbin/$$n $(ROOTFS)/usr/bin/$$n; \
	done
	cp -a $(LLVM_INST)/usr/. $(ROOTFS)/usr/
	cp -a $(SYSROOT)/usr/include/. $(ROOTFS)/usr/include/
	cp -a $(SYSROOT)/usr/lib/. $(ROOTFS)/usr/lib/
	@touch $@

# The initramfs must be built after the install.
$(INITRD): $(STAMP)/llvm.rootfs
