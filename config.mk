# SimpleLinux configuration (versions checked 2026-10-27)

NAME    := SimpleLinux
VERSION := 0.1
TARGET  := x86_64-linux-musl
KARCH   := x86
CLANG   ?= clang
JOBS    ?= $(shell nproc)

LINUX_VERSION   := 6.18.59
MUSL_VERSION    := 1.2.6
BUSYBOX_VERSION := 1.38.0

LINUX_URL   = https://cdn.kernel.org/pub/linux/kernel/v$(word 1,$(subst ., ,$(LINUX_VERSION))).x/linux-$(LINUX_VERSION).tar.xz
MUSL_URL    = https://musl.libc.org/releases/musl-$(MUSL_VERSION).tar.gz
BUSYBOX_URL = https://busybox.net/downloads/busybox-$(BUSYBOX_VERSION).tar.bz2
