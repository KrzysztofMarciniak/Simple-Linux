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
	@set -e; \
	config=$(KOUT)/.config; \
	set_config() { \
	  sed "/^CONFIG_$$1=/d; /^# CONFIG_$$1 is not set$$/d" "$$config" > "$$config.tmp"; \
	  printf 'CONFIG_%s=y\n' "$$1" >> "$$config.tmp"; \
	  mv "$$config.tmp" "$$config"; \
	}; \
	for option in E1000 E1000E R8169 VIRTIO_NET KEYS BLK_DEV_DM DM_CRYPT; do \
	  set_config "$$option"; \
	done
	$(MAKE) -C $(LINUX_SRC) O=$(KOUT) LLVM=1 ARCH=$(KARCH) olddefconfig
	KBUILD_BUILD_TIMESTAMP='' $(MAKE) -C $(LINUX_SRC) O=$(KOUT) LLVM=1 ARCH=$(KARCH) \
	    CC="$(strip $(if $(filter ON,$(TARGET_CCACHE)),$(CCACHE)) clang)" \
	    -j$(KERNEL_JOBS) bzImage
	@touch $@
