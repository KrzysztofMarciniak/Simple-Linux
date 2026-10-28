#!/bin/sh
qemu-system-x86_64 \
  -kernel build/linux-out/arch/x86/boot/bzImage \
  -initrd build/initramfs.gz \
  -append "console=ttyS0,115200 rdinit=/init" \
  -nographic
