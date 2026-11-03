# ---- kernel headers (for musl and userland) --------------------------------
$(STAMP)/headers.built: $(STAMP)/linux.unpacked $(CURDIR)/mk/kernel.mk $(CURDIR)/config.mk
	@mkdir -p $(KOUT) $(SYSROOT)/usr
	$(MAKE) -C $(LINUX_SRC) O=$(KOUT) LLVM=1 ARCH=$(KARCH) \
	    INSTALL_HDR_PATH=$(SYSROOT)/usr headers_install
	@touch $@

# ---- kernel ----------------------------------------------------------------
$(STAMP)/kernel.built: $(STAMP)/linux.unpacked $(STAMP)/target.ccache $(CURDIR)/mk/kernel.mk $(CURDIR)/config.mk
	@mkdir -p $(KOUT)
	$(MAKE) -C $(LINUX_SRC) O=$(KOUT) LLVM=1 ARCH=$(KARCH) defconfig
	$(LINUX_SRC)/scripts/config --file $(KOUT)/.config \
	    --enable E1000 --enable E1000E --enable R8169 --enable VIRTIO_NET
	$(MAKE) -C $(LINUX_SRC) O=$(KOUT) LLVM=1 ARCH=$(KARCH) olddefconfig
	KBUILD_BUILD_TIMESTAMP='' $(MAKE) -C $(LINUX_SRC) O=$(KOUT) LLVM=1 ARCH=$(KARCH) \
	    CC="$(strip $(if $(filter ON,$(TARGET_CCACHE)),$(CCACHE)) clang)" \
	    -j$(KERNEL_JOBS) bzImage
	@touch $@
