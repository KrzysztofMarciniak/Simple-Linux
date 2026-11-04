# Download and unpack source archives.
MANDOC_VERSION := 1.14.6
MANDOC_URL := https://mandoc.bsd.lv/snapshots/mandoc-$(MANDOC_VERSION).tar.gz
ZLIB_VERSION := 1.3.2
ZLIB_URL := https://zlib.net/zlib-$(ZLIB_VERSION).tar.gz
OPENSSL_VERSION := 3.5.9
OPENSSL_URL := https://github.com/openssl/openssl/releases/download/openssl-$(OPENSSL_VERSION)/openssl-$(OPENSSL_VERSION).tar.gz
PERL_VERSION := 5.44.0
PERL_URL := https://www.cpan.org/src/5.0/perl-$(PERL_VERSION).tar.gz
PERL_CROSS_VERSION := 1.6.5
PERL_CROSS_URL := https://github.com/arsv/perl-cross/releases/download/$(PERL_CROSS_VERSION)/perl-cross-$(PERL_CROSS_VERSION).tar.gz
CRYPTSETUP_VERSION := 2.8.8
CRYPTSETUP_URL := https://www.kernel.org/pub/linux/utils/cryptsetup/v2.8/cryptsetup-$(CRYPTSETUP_VERSION).tar.xz
LVM2_VERSION := 2.03.43
LVM2_URL := https://sourceware.org/pub/lvm2/releases/LVM2.$(LVM2_VERSION).tgz
POPT_VERSION := 1.19
POPT_URL := https://ftp.osuosl.org/pub/rpm/popt/releases/popt-1.x/popt-$(POPT_VERSION).tar.gz
JSON_C_VERSION := 0.19
JSON_C_RELEASE := json-c-0.19-20260627
JSON_C_URL := https://github.com/json-c/json-c/releases/download/$(JSON_C_RELEASE)/json-c-$(JSON_C_VERSION).tar.gz
UTIL_LINUX_VERSION := 2.42.4
UTIL_LINUX_URL := https://www.kernel.org/pub/linux/utils/util-linux/v2.42/util-linux-$(UTIL_LINUX_VERSION).tar.xz
KMOD_VERSION := 34
KMOD_URL := https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-$(KMOD_VERSION).tar.xz
MKINITRD_COMMIT := f825813f356bc52925d9654c7b9ad65b15f0fda7
MKINITRD_URL := https://codeberg.org/emmett1/mkinitrd/archive/$(MKINITRD_COMMIT).tar.gz
GRUB_VERSION := 2.14
GRUB_URL := https://ftp.gnu.org/gnu/grub/grub-$(GRUB_VERSION).tar.xz
LIBBURN_VERSION := 1.5.8
LIBBURN_URL := https://files.libburnia-project.org/releases/libburn-$(LIBBURN_VERSION).tar.gz
LIBISOFS_VERSION := 1.5.8.pl02
LIBISOFS_URL := https://files.libburnia-project.org/releases/libisofs-$(LIBISOFS_VERSION).tar.gz
LIBISOBURN_VERSION := 1.5.8.pl02
LIBISOBURN_URL := https://files.libburnia-project.org/releases/libisoburn-$(LIBISOBURN_VERSION).tar.gz
M4_VERSION := 1.4.20
M4_URL := https://ftp.gnu.org/gnu/m4/m4-$(M4_VERSION).tar.xz
BISON_VERSION := 3.8.2
BISON_URL := https://ftp.gnu.org/gnu/bison/bison-$(BISON_VERSION).tar.xz
FLEX_VERSION := 2.6.4
FLEX_URL := https://github.com/westes/flex/releases/download/v$(FLEX_VERSION)/flex-$(FLEX_VERSION).tar.gz
PKGCONF_VERSION := 2.3.0
PKGCONF_URL := https://distfiles.ariadne.space/pkgconf/pkgconf-$(PKGCONF_VERSION).tar.xz

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
$(eval $(call PKG,python,$(PYTHON_URL)))
$(eval $(call PKG,llvm,$(LLVM_URL)))
$(eval $(call PKG,make,$(MAKE_URL)))
$(eval $(call PKG,mandoc,$(MANDOC_URL)))
$(eval $(call PKG,zlib,$(ZLIB_URL)))
$(eval $(call PKG,openssl,$(OPENSSL_URL)))
$(eval $(call PKG,perl,$(PERL_URL)))
$(eval $(call PKG,perl-cross,$(PERL_CROSS_URL)))
$(eval $(call PKG,cryptsetup,$(CRYPTSETUP_URL)))
$(eval $(call PKG,lvm2,$(LVM2_URL)))
$(eval $(call PKG,popt,$(POPT_URL)))
$(eval $(call PKG,json-c,$(JSON_C_URL)))
$(eval $(call PKG,util-linux,$(UTIL_LINUX_URL)))
$(eval $(call PKG,kmod,$(KMOD_URL)))
$(eval $(call PKG,mkinitrd,$(MKINITRD_URL)))
$(eval $(call PKG,grub,$(GRUB_URL)))
$(eval $(call PKG,libburn,$(LIBBURN_URL)))
$(eval $(call PKG,libisofs,$(LIBISOFS_URL)))
$(eval $(call PKG,libisoburn,$(LIBISOBURN_URL)))
$(eval $(call PKG,m4,$(M4_URL)))
$(eval $(call PKG,bison,$(BISON_URL)))
$(eval $(call PKG,flex,$(FLEX_URL)))
$(eval $(call PKG,pkgconf,$(PKGCONF_URL)))

LINUX_SRC   := $(SRC)/linux-$(LINUX_VERSION)
MUSL_SRC    := $(SRC)/musl-$(MUSL_VERSION)
BUSYBOX_SRC := $(SRC)/busybox-$(BUSYBOX_VERSION)
ARK_SRC     := $(SRC)/Ark-$(ARK_VERSION)
PYTHON_SRC  := $(SRC)/Python-$(PYTHON_VERSION)
LLVM_SRC := $(SRC)/llvm-project-$(LLVM_VERSION).src
MAKE_SRC  := $(SRC)/make-$(MAKE_VERSION)
MANDOC_SRC := $(SRC)/mandoc-$(MANDOC_VERSION)
ZLIB_SRC := $(SRC)/zlib-$(ZLIB_VERSION)
OPENSSL_SRC := $(SRC)/openssl-$(OPENSSL_VERSION)
PERL_SRC := $(SRC)/perl-$(PERL_VERSION)
PERL_CROSS_SRC := $(SRC)/perl-cross-$(PERL_CROSS_VERSION)
CRYPTSETUP_SRC := $(SRC)/cryptsetup-$(CRYPTSETUP_VERSION)
LVM2_SRC := $(SRC)/LVM2.$(LVM2_VERSION)
POPT_SRC := $(SRC)/popt-$(POPT_VERSION)
JSON_C_SRC := $(SRC)/json-c-$(JSON_C_VERSION)
UTIL_LINUX_SRC := $(SRC)/util-linux-$(UTIL_LINUX_VERSION)
KMOD_SRC := $(SRC)/kmod-$(KMOD_VERSION)
MKINITRD_SRC := $(SRC)/mkinitrd
GRUB_SRC := $(SRC)/grub-$(GRUB_VERSION)
LIBBURN_SRC := $(SRC)/libburn-$(LIBBURN_VERSION)
LIBISOFS_SRC := $(SRC)/libisofs-1.5.8
LIBISOBURN_SRC := $(SRC)/libisoburn-1.5.8
M4_SRC := $(SRC)/m4-$(M4_VERSION)
BISON_SRC := $(SRC)/bison-$(BISON_VERSION)
FLEX_SRC := $(SRC)/flex-$(FLEX_VERSION)
PKGCONF_SRC := $(SRC)/pkgconf-$(PKGCONF_VERSION)
