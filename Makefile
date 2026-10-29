
# SimpleLinux build orchestrator. Phase rules live in mk/.
include config.mk

.DEFAULT_GOAL := iso
.PHONY: iso clean rootfs bare minimal toolchain FORCE

# bash is needed for `read -s` in the password prompt.
SHELL := /bin/bash

DL      := $(CURDIR)/downloads
B       := $(CURDIR)/build
SRC     := $(B)/src
STAMP   := $(B)/stamps
SYSROOT := $(B)/sysroot
ROOTFS  := $(B)/rootfs
KOUT    := $(B)/linux-out
INITRD  := $(B)/initramfs.gz
ISO     := $(CURDIR)/$(NAME)-$(VERSION).iso
CREDS   := $(B)/credentials

# PROFILE: bare | minimal. Reuse the last built profile if unspecified.
ifndef PROFILE
PROFILE := $(or $(shell cat $(STAMP)/profile 2>/dev/null),bare)
endif

# Minimal profile defaults.
MIN_USER     ?= 0x00
MIN_UID      ?= 1000
MIN_GID      ?= $(MIN_UID)
MIN_HOSTNAME ?= antarctica

# Userland compiler: the host's default cc, static.
CC_SYS := cc -static

include mk/sources.mk
include mk/profiles.mk
include mk/kernel.mk
include mk/userland.mk
include mk/toolchain.mk
include mk/rootfs.mk
include mk/image.mk
