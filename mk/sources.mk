# Download and unpack source archives.
define PKG
$(DL)/$(notdir $(2)):
	@mkdir -p $(DL)
	curl -fL --retry 3 -o $$@.part $(2)
	@mv $$@.part $$@
$(STAMP)/$(1).unpacked: $(DL)/$(notdir $(2))
	@mkdir -p $(SRC) $(STAMP)
	tar -xf $$< -C $(SRC)
	@touch $$@
endef

$(eval $(call PKG,linux,$(LINUX_URL)))
$(eval $(call PKG,musl,$(MUSL_URL)))
$(eval $(call PKG,busybox,$(BUSYBOX_URL)))
$(eval $(call PKG,ark,$(ARK_URL)))
$(eval $(call PKG,llvm,$(LLVM_URL)))

LINUX_SRC   := $(SRC)/linux-$(LINUX_VERSION)
MUSL_SRC    := $(SRC)/musl-$(MUSL_VERSION)
BUSYBOX_SRC := $(SRC)/busybox-$(BUSYBOX_VERSION)
ARK_SRC     := $(SRC)/Ark-$(ARK_VERSION)
LLVM_SRC := $(SRC)/llvm-project-$(LLVM_VERSION).src
