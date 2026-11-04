# ---- initramfs (gen_init_cpio creates /dev nodes without root) -------------
$(INITRD): $(STAMP)/rootfs.done $(STAMP)/linux.unpacked $(CURDIR)/mk/image.mk
ifeq ($(PROFILE),minimal)
$(INITRD): $(STAMP)/manpages.rootfs
$(INITRD): $(STAMP)/openssl.rootfs
$(INITRD): $(STAMP)/ca-certs.rootfs
$(INITRD): $(STAMP)/luks.rootfs
$(INITRD): $(STAMP)/mkinitrd.rootfs
$(INITRD): $(STAMP)/grub.rootfs
endif
	cc -o $(B)/gen_init_cpio $(LINUX_SRC)/usr/gen_init_cpio.c
	cd $(ROOTFS) && { \
	  find . -mindepth 1 -type d -printf 'dir /%P %m 0 0\n'; \
	  find . -type f -printf 'file /%P %p %m 0 0\n'; \
	  find . -type l -printf 'slink /%P %l %m 0 0\n'; \
	  echo 'nod /dev/console 0600 0 0 c 5 1'; \
	  echo 'nod /dev/null 0666 0 0 c 1 3'; \
	} > $(B)/initramfs.list
ifeq ($(PROFILE),minimal)
	sed -E -i 's@^((dir|file) /home/$(MIN_USER)(/[^ ]*)? .*) 0 0$$@\1 $(MIN_UID) $(MIN_GID)@' $(B)/initramfs.list
endif
	cd $(ROOTFS) && $(B)/gen_init_cpio $(B)/initramfs.list | gzip -1 > $@

# ---- ISO -------------------------------------------------------------------
iso: $(ISO)

$(ISO): $(STAMP)/kernel.built $(INITRD) $(STAMP)/grub.host.efi.built \
        $(CURDIR)/mk/image.mk $(CURDIR)/config.mk
	rm -rf $(B)/iso
	mkdir -p $(B)/iso/boot/grub
	cp $(KOUT)/arch/$(KARCH)/boot/bzImage $(B)/iso/boot/vmlinuz
	cp $(INITRD) $(B)/iso/boot/initramfs.gz
	printf '%s\n' \
	  'set timeout=5' \
	  'set debug=linux' \
	  'insmod serial' \
	  'serial --unit=0 --speed=115200' \
	  'terminal_input --append serial' \
	  'terminal_output --append serial' \
	  'set superusers="root"' \
	  'insmod password_pbkdf2' \
	  'password_pbkdf2 root grub.pbkdf2.sha512.100000.4C9BE8842EFE37E2CDB67FEA57C424852393FE822CE0D5833B9CBFC78825A2138FBAC83C423F316F48C28E8516108D8CB3E47EE8953D2213D9918DEE5AB64DBC.90C499431AD930CEC9F447BB70FFE1A92EFB05AC4CB05786DB862D7E91376DECA9A5A26D2038638E7B0EDDB70B756A3254FDC1656652DBA4380CB204FA7E221B' \
	  'menuentry "$(NAME)" {' \
	  '  linux /boot/vmlinuz rdinit=/init ignore_loglevel loglevel=8 earlyprintk=vga,keep earlyprintk=efi,keep earlyprintk=ttyS0,115200 console=tty0 console=ttyS0,115200' \
	  '  initrd /boot/initramfs.gz' \
	  '}' > $(B)/iso/boot/grub/grub.cfg
	LD_LIBRARY_PATH="$(GRUB_HOST_LIB):$${LD_LIBRARY_PATH}" \
	  $(GRUB_HOST_PREFIX)/bin/grub-mkrescue \
	  --xorriso=$(GRUB_HOST_LIBISOBURN_INST)/usr/bin/xorriso -o $@ $(B)/iso

clean:
	rm -rf $(B) $(ISO)

FORCE:

rootfs:
	rm -f $(STAMP)/rootfs.done $(INITRD) $(ISO)
	$(MAKE) PROFILE=$(PROFILE) iso
