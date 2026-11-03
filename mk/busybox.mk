# ---- BusyBox (dynamic, musl; userland + init) ------------------------------
BUSYBOX_CONFIG := $(CURDIR)/busybox.config
BUSYBOX_CC := $(if $(filter ON,$(BUSYBOX_CCACHE)),$(CCACHE) ,)$(CC_SYS)

$(STAMP)/busybox.ccache: FORCE
	@mkdir -p $(STAMP)
	@printf '%s\n' '$(BUSYBOX_CCACHE)' '$(CCACHE)' | cmp -s - $@ || printf '%s\n' '$(BUSYBOX_CCACHE)' '$(CCACHE)' > $@

# Apply the project fragment to an allnoconfig baseline; BusyBox 1.38 does not
# merge KCONFIG_ALLCONFIG entries for this target.
$(STAMP)/busybox.built: $(STAMP)/busybox.unpacked $(STAMP)/musl.built $(STAMP)/llvm.built $(STAMP)/busybox.ccache $(CURDIR)/mk/busybox.mk $(BUSYBOX_CONFIG)
	# empty stub so the clang driver's implicit -lssp_nonshared resolves
	$(abspath $(LLVM_INST))/usr/bin/llvm-ar rc $(abspath $(SYSROOT))/usr/lib/libssp_nonshared.a
	cd $(BUSYBOX_SRC) && \
	  $(MAKE) CC="$(BUSYBOX_CC)" HOSTCC=cc allnoconfig && \
	  while IFS='=' read -r key value; do \
	    case "$$key" in CONFIG_*) \
	      sed -i \
	        -e "s/^# $$key is not set$$/$$key=$$value/" \
	        -e "s/^$$key=.*/$$key=$$value/" \
	        .config ;; \
	    esac; \
	  done < $(BUSYBOX_CONFIG) && \
	  sed -i \
	    -e 's|^CONFIG_EXTRA_CFLAGS=.*|CONFIG_EXTRA_CFLAGS="-fno-stack-protector"|' \
	    -e 's|^CONFIG_EXTRA_LDFLAGS=.*|CONFIG_EXTRA_LDFLAGS="-fuse-ld=lld -B$(abspath $(LLVM_INST))/usr/bin -no-pie -rtlib=compiler-rt -unwindlib=none"|' \
	    -e 's|^CONFIG_EXTRA_LDLIBS=.*|CONFIG_EXTRA_LDLIBS=""|' \
	    .config && \
	  yes "" | $(MAKE) CC="$(BUSYBOX_CC)" HOSTCC=cc oldconfig && \
	  $(MAKE) -j$(JOBS) CC="$(BUSYBOX_CC)" HOSTCC=cc && \
	  $(MAKE) CC="$(BUSYBOX_CC)" HOSTCC=cc CONFIG_PREFIX=$(ROOTFS) install
	mkdir -p $(ROOTFS)/lib
	cp -f $(SYSROOT)/usr/lib/libc.so $(ROOTFS)$(MUSL_LD)
	chmod 755 $(ROOTFS)$(MUSL_LD)
	@touch $@
