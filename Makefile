# SimpleLinux build orchestrator. Phase rules live in mk/.
include config.mk

.DEFAULT_GOAL := iso
.PHONY: iso clean rootfs bare minimal toolchain FORCE

SHELL := /bin/sh

DL      := $(CURDIR)/downloads
B       := $(CURDIR)/build
SRC     := $(B)/src
STAMP   := $(B)/stamps
SYSROOT := $(B)/sysroot
ROOTFS  := $(B)/rootfs
KOUT    := $(B)/linux-out
INITRD  := $(B)/initramfs.gz
ISO     := $(CURDIR)/$(NAME)-$(VERSION).iso

# PROFILE: bare | minimal. Reuse the last built profile if unspecified.
ifndef PROFILE
PROFILE := $(or $(shell cat $(STAMP)/profile 2>/dev/null),bare)
endif

# Minimal profile defaults.
MIN_USER     ?= 0x00
MIN_UID      ?= 1000
MIN_GID      ?= $(MIN_UID)
MIN_HOSTNAME ?= antarctica
ROOT_PASSWD  ?= root
USER_PASS    ?= 0x00

KOUT    := $(B)/linux-out
LLVM_INST := $(B)/llvm-install

# Userland compiler: clang targeting musl, dynamic, using our sysroot.
CC_SYS = $(abspath $(LLVM_INST))/usr/bin/clang --target=x86_64-linux-musl --sysroot=$(abspath $(SYSROOT)) -rtlib=compiler-rt -unwindlib=none
MUSL_LD := /lib/ld-musl-x86_64.so.1

include mk/sources.mk
include mk/profiles.mk
include mk/kernel.mk
include mk/userland.mk
include mk/toolchain.mk
include mk/rootfs.mk
include mk/image.mk
