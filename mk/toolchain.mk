# ---- LLVM seed toolchain (clang + lld), musl target, dynamic ---
LLVM_BUILD := $(B)/llvm-build

.PHONY: toolchain
toolchain: $(STAMP)/llvm.built

$(STAMP)/llvm.built: $(STAMP)/llvm.unpacked
	env -u LDFLAGS -u CFLAGS -u CXXFLAGS -u CPPFLAGS \
	cmake -S $(LLVM_SRC)/llvm -B $(LLVM_BUILD) \
	  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
	  -DCMAKE_C_COMPILER=cc -DCMAKE_CXX_COMPILER=c++ \
	  -DLLVM_ENABLE_PROJECTS='clang;lld' \
	  -DLLVM_ENABLE_RUNTIMES= \
	  -DCMAKE_EXE_LINKER_FLAGS= \
	  -DCMAKE_SHARED_LINKER_FLAGS= \
	  -DLLVM_BUILD_STATIC=OFF \
	  -DLIBCLANG_BUILD_STATIC=OFF \
	  -DLLVM_STATIC_LINK_CXX_STDLIB=OFF \
	  -DLLVM_BUILD_LLVM_DYLIB=ON \
	  -DLLVM_LINK_LLVM_DYLIB=ON \
	  -DCLANG_LINK_CLANG_DYLIB=ON \
	  -DLLVM_TARGETS_TO_BUILD=X86 \
	  -DLLVM_DEFAULT_TARGET_TRIPLE=$(TARGET) \
	  -DCLANG_DEFAULT_RTLIB=libgcc \
	  -DCLANG_DEFAULT_LINKER=lld \
	  -DCLANG_DEFAULT_UNWINDLIB=none \
	  -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
	  -DLLVM_INSTALL_BINUTILS_SYMLINKS=ON \
	  -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF \
	  -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_DOCS=OFF \
	  -DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF \
	  -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_ENABLE_TERMINFO=OFF
	@echo '== link flags for llvm-cat:'
	@tr ' ' '\n' < $(LLVM_BUILD)/tools/llvm-cat/CMakeFiles/llvm-cat.dir/link.txt | grep -E '^-static|^-lLLVM|libLLVM' || true
	env -u LDFLAGS cmake --build $(LLVM_BUILD) --target LLVM -j$(JOBS)
	env -u LDFLAGS cmake --build $(LLVM_BUILD) -j$(JOBS)
	DESTDIR=$(ROOTFS) cmake --install $(LLVM_BUILD) --strip
	mkdir -p $(ROOTFS)/lib $(ROOTFS)/usr/lib
	cp -L $(SYSROOT)/usr/lib/libc.so $(ROOTFS)/lib/ld-musl-x86_64.so.1
	ln -sf ld-musl-x86_64.so.1 $(ROOTFS)/lib/libc.musl-x86_64.so.1
	cp -L /usr/lib/libstdc++.so.6 /usr/lib/libgcc_s.so.1 $(ROOTFS)/usr/lib/
	@touch $@
