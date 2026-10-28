# ---- initramfs (gen_init_cpio creates /dev nodes without root) -------------
$(INITRD): $(STAMP)/rootfs.done $(STAMP)/linux.unpacked
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
	cd $(ROOTFS) && $(B)/gen_init_cpio $(B)/initramfs.list | gzip -9 > $@

# ---- ISO -------------------------------------------------------------------
iso: $(ISO)

$(ISO): $(STAMP)/kernel.built $(INITRD)
	rm -rf $(B)/iso
	mkdir -p $(B)/iso/boot/grub
	cp $(KOUT)/arch/$(KARCH)/boot/bzImage $(B)/iso/boot/vmlinuz
	cp $(INITRD) $(B)/iso/boot/initramfs.gz
	printf 'set timeout=0\nmenuentry "%s" {\n  linux /boot/vmlinuz console=tty0 console=ttyS0\n  initrd /boot/initramfs.gz\n}\n' \
	    "$(NAME)" > $(B)/iso/boot/grub/grub.cfg
	grub-mkrescue -o $@ $(B)/iso

clean:
	rm -rf $(B) $(ISO)

FORCE:

rootfs:
	rm -f $(STAMP)/rootfs.done $(INITRD) $(ISO)
	$(MAKE) PROFILE=$(PROFILE) iso
