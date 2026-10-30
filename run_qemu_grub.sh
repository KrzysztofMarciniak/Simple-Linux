#!/bin/sh
qemu-system-x86_64 \
  -cdrom SimpleLinux-0.1.iso \
  -boot d \
  -m 2G \
  -serial stdio
