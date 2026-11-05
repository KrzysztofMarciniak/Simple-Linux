# SimpleLinux

![Project logo](Logo.png)

> **Work in progress — not yet a self-hosting distribution.**

SimpleLinux is an x86_64 Linux distribution built around the Linux kernel,
musl libc, BusyBox, and LLVM/Clang. The **Minimal** profile is intended to be
a practical C development and maintenance system that can rebuild itself from
source without an internet connection.

That goal is not complete yet. The repository has build rules for most of the
Minimal software, but a build rule or an installed executable is not proof
that a clean installed system can rebuild that software. The checklist below
tracks that gap explicitly. The known kernel blockers are missing libelf
development files and the missing `llvm-readelf` name in the inspected
rootfs, although the build rule expects to provide it.

System packages are managed by SimpleLinux's root-level system package
manager. [Ark](https://github.com/KrzysztofMarciniak/Ark) is user-only: it
installs packages under `~/.ark` and does not manage system files. BusyBox
init is PID 1; [Lilith](#services) manages services through `/etc/inittab`.
SimpleLinux does not use systemd, D-Bus, or polkit.

![SimpleLinux desktop](simple.png)

## Profiles

Only these profiles are currently defined by the build:

| Profile | Contents |
|---------|----------|
| **Bare** | Linux kernel, musl libc, and BusyBox. |
| **Minimal** | Bare plus LLVM/Clang, Ark, build tools, boot and disk tools, networking helpers, and the libraries and utilities catalogued below. Intended for development and system maintenance. |

Minimal + X11 and the other software ideas formerly listed here are not
implemented profiles or promises of package availability.

## Build and test

The project builds the ISO and its components with GNU Make. A build host
needs a C/C++ toolchain, GNU Make, CMake, Python 3, Bison, Flex, pkg-config,
Meson, Ninja, `curl`, `tar`, and the OpenSSL CLI (used for password hashes).
Host Bison, Flex, pkg-config, Meson, and Ninja are used by parts of the
initial build; they are separate from the target packages in Minimal.
Generating the manuals also uses host Python and the pinned packages in
`mk/manpages-requirements.txt`.

Build the default Bare profile or select Minimal explicitly:

```sh
make
make minimal
```

Force regeneration of the root filesystem, initramfs, and ISO with
`make rootfs`. Limit parallelism with `JOBS=2`; kernel parallelism can be
controlled separately with `KERNEL_JOBS=2`. Remove generated output while
keeping downloaded sources with `make clean`.

Boot the ISO in QEMU:

```sh
./run_qemu.sh
```

The installation test runner uses a persistent disposable disk:

```sh
./run_qemu_test_install.sh
# In the live system:
cp /install/config.example /install/config
vi /install/config
DISK=sdb /install/install.sh
# After shutting down QEMU:
BOOT_INSTALLED=1 ./run_qemu_test_install.sh
```

The test disk is stored under `build/qemu-install-test/`;
`RESET_DISK=1 ./run_qemu_test_install.sh` recreates it. UEFI tests use
`FIRMWARE=uefi` and host `OVMF_CODE` and `OVMF_VARS` paths.

Installation is **encrypted-only**: the installer erases the selected disk,
creates a GPT layout, leaves the EFI system partition unencrypted, and places
the ext4 root inside LUKS2. GRUB requires a password, which is authentication
and does not encrypt GRUB, the EFI partition, or the ISO. Read
`install/config.example` carefully before installing.

## System package updates

Minimal includes a root-level system package manager, separate from Ark.
Ark remains user-only and installs under `~/.ark`; it does not manage system
files. Each updateable system component has a `/usr/sbin/system-update-*`
entry point. Each updater contains its own Make target, staging directory,
version pin, and latest-source lookup, following the existing build rules.
`system-update` is the batch runner; it invokes those component scripts in
sequence.
For example:

```sh
system-update-m4 recompile
system-update-m4 update 1.4.20
system-update-cmake latest
system-update-cmake update latest
system-update-m4 status
system-update-m4 recover
system-update                 # update all managed packages to latest
system-update latest          # print all resolved versions
system-update recompile       # rebuild all managed packages
system-update status
```

`recompile` builds the repository-pinned (or installed) version;
`update VERSION` fetches and builds an explicitly supplied upstream version.
`update latest` resolves and builds that component's current upstream version.
The batch runner defaults to `update latest`; it processes components in
sequence and stops on the first failure, so earlier successful updates may
already be staged. `system-update latest` resolves versions without building.
Lilith is shipped as a service script and is not updated by this system.
Perl remains excluded because its existing build fails.
Build as a normal user from a SimpleLinux source checkout (default
`/usr/src/simplelinux`, or set `SYSTEM_BUILD_ROOT`); only staging the package
and scheduling recovery require root. The checkout needs the normal build
dependencies.
Staged files are activated by the boot-time system package manager at the
next reboot, not immediately. The manager keeps the prior package files;
`recover` schedules restoring them at the next reboot. Existing `/etc` files
are preserved and replacement configuration files are installed as `.new`.

The current build graph has package-specific staging adapters for GNU Make,
CMake, CPython, Meson, Ninja, M4, Bison, Flex, pkgconf, zlib, mandoc, OpenSSL,
CA data, popt, json-c, util-linux, LVM2 device-mapper, cryptsetup, e2fsprogs,
Ark, musl, BusyBox, the coordinated LLVM compiler/runtime toolchain,
libatomic, Linux and its modules, GRUB and its target ISO libraries, kmod,
and mkinitrd. LLVM, libc++, libc++abi, libunwind, and libatomic share
one package update so their compiler/runtime ABI remains synchronized. The
Linux updater stages the kernel and matching modules together; activation
rebuilds the installed initramfs against them and rolls back if that rebuild
fails. Perl remains excluded because its existing build is failing.

## Minimal software and self-rebuild checklist

This is the complete explicit package/source inventory in the current Bare
and Minimal build graph. BusyBox applets are grouped under BusyBox; generated
manual pages and firmware modules are listed with their producing packages.
An unchecked box means a rebuild from a clean installed SimpleLinux system
has not been demonstrated. Source rules, staged files, and successful builds
on another host do not count as that test.

### Base system and compiler

| Rebuild check | Program or library | Version / role | Current self-rebuild status |
|---|---|---|---|
| [ ] | Linux kernel | 6.18.59; x86_64 kernel, installed headers, and build-host `gen_init_cpio` | **Blocked:** libelf headers/library are missing and `llvm-readelf` is absent from the inspected rootfs. |
| [ ] | musl libc | 1.2.6; system C library and dynamic loader | Not verified from an installed system. |
| [ ] | BusyBox | 1.38.0; init, shell, core utilities, and configured applets | Not verified from an installed system. |
| [ ] | LLVM/Clang | 21.1.8; Clang, LLD, LLVM tools, and compiler-rt | Build rules exist; self-rebuild is not verified. |
| [ ] | libc++, libc++abi, libunwind | LLVM C++ runtime and headers | Included in the LLVM runtime build; self-rebuild is not verified. |
| [ ] | libatomic | compiler-rt atomic operations, built as `libatomic.so.1` | Build rule exists; self-rebuild is not verified. |
| [ ] | Ark | 1.0; system-installed command for managing user-local packages | Rebuild its binary with the system package manager; Ark itself only installs under `~/.ark`. |

### Build tools and source generators

| Rebuild check | Program or library | Version / role | Current self-rebuild status |
|---|---|---|---|
| [ ] | GNU Make | 4.4.1; build orchestration | Target package rule exists; bootstrap/rebuild is not verified. |
| [ ] | CMake | 4.4.5; LLVM and other CMake builds | Target package rule exists; not runtime-verified. |
| [ ] | CPython | 3.15.2; build scripts and Meson | Cross-build rule exists; not runtime-verified. |
| [ ] | Meson | 1.12.1; kmod and Meson projects | Target package rule exists; not runtime-verified. |
| [ ] | Ninja | 1.13.2; Meson/CMake build backend | Target package rule exists; not runtime-verified. |
| [ ] | M4 | 1.4.20; macro processor | Target package rule exists; not runtime-verified. |
| [ ] | Bison | 3.8.2; parser generator | Target package rule exists; not runtime-verified. |
| [ ] | Flex | 2.6.4; lexer generator | Target package rule exists; not runtime-verified. |
| [ ] | pkgconf / `pkg-config` | 2.3.0; library discovery and build flags | Target package rule exists; not runtime-verified. |

### Libraries and system programs

| Rebuild check | Program or library | Version / role | Current self-rebuild status |
|---|---|---|---|
| [ ] | zlib | 1.3.2; compressed-manual support for mandoc | Target build rule exists; not runtime-verified. |
| [ ] | mandoc | 1.14.6; `man` reader and manual database tools | Target build rule exists; not runtime-verified. |
| [ ] | OpenSSL | 3.5.9; `openssl`, `libssl`, `libcrypto`, and headers | Target build rule exists; not runtime-verified. |
| [ ] | Mozilla CA bundle | 2026-10-20; TLS trust data, not a compiled library | Pinned and staged by a rule; HTTPS verification is not runtime-verified. |
| [ ] | GRUB | 2.14; target utilities and BIOS/UEFI modules | Target build rules exist; installed-system rebuild is not verified. |
| [ ] | libburn, libisofs, libisoburn / xorriso | 1.5.8, 1.5.8.pl02, 1.5.8.pl02; ISO creation stack | Target stack and native ISO-build rules exist; not runtime-verified. |
| [ ] | kmod | 34; `kmod`, `modprobe`, `modinfo`, `depmod`, and `libkmod` | Target build rule exists; not runtime-verified. |
| [ ] | mkinitrd | BusyBox-based initramfs generator and hooks | Script/source is staged; generated initramfs behavior is not fully validated. |
| [ ] | popt | 1.19; command-line parsing library | Target build rule exists; not runtime-verified. |
| [ ] | json-c | 0.19; JSON library | Target build rule exists; not runtime-verified. |
| [ ] | util-linux libraries and `sfdisk` | 2.42.4; libuuid, libblkid, libsmartcols, libfdisk, partitioning | Target build rule exists; not runtime-verified. |
| [ ] | LVM2 device-mapper | 2.03.43; `libdevmapper` for cryptsetup | Target build rule exists; not runtime-verified. |
| [ ] | cryptsetup | 2.8.8; LUKS tools and `libcryptsetup` | Target build rule exists; not runtime-verified. |
| [ ] | e2fsprogs | 1.47.4; ext4 formatting tools and `libext2fs` | Target build rule exists; not runtime-verified. |
| [ ] | Lilith and SimpleLinux scripts | POSIX shell service manager, installer, network helpers, and `su` wrappers | Scripts are staged; persistence, service, network, and install tests remain. |

Perl 5.44.0 and perl-cross 1.6.5 have source pins and a build recipe, but the
recipe currently fails and Perl is excluded from Minimal. It is **not** part
of the installed package inventory. No libelf package is currently built or
staged. The LLVM and Clang manuals are generated during the host ISO build;
Sphinx 7.2.6, Docutils 0.20.1, Myst Parser 2.0.0, and PyYAML 6.0.2 are host
build dependencies, not Minimal target packages.

### What must pass before calling Minimal self-hosting

- [ ] Boot and install Minimal, then complete each applicable row above from
  the installed system using its own compiler and libraries.
- [ ] Add and stage libelf development headers and library; confirm Kbuild's
  `llvm-readelf` requirement is met.
- [ ] Rebuild Linux, musl, BusyBox, LLVM/Clang, and the LLVM runtime from
  locally retained sources, then install and boot the rebuilt system.
- [ ] Rebuild every other listed system package through its system updater.
- [ ] Test Ark-managed user packages separately; Ark must not modify system
  files.
- [ ] Repeat from a clean install with networking disabled and without
  depending on the original build host's `build/` directory or compiler.
- [ ] Verify the rebuilt ISO and encrypted installation boot and can recover.

## Offline rebuilds

The target system alone is not enough: an offline rebuild also needs the
repository checkout, every exact source archive referenced by `mk/sources.mk`,
and any build-only inputs. Keep the archives under `downloads/`; otherwise the
download rules invoke host `curl`. The configured source set includes:

| Component | Pinned source |
|---|---|
| Base and compiler | Linux 6.18.59, musl 1.2.6, BusyBox 1.38.0, Ark 1.0, LLVM 21.1.8, GNU Make 4.4.1 |
| Build tools | Python 3.15.2, CMake 4.4.5, Meson 1.12.1, Ninja 1.13.2 |
| Manuals and TLS | mandoc 1.14.6, zlib 1.3.2, OpenSSL 3.5.9, CA bundle dated 2026-10-20 |
| Crypto and disk | cryptsetup 2.8.8, LVM2 2.03.43, popt 1.19, json-c 0.19, util-linux 2.42.4, e2fsprogs 1.47.4 |
| Kernel modules | kmod 34, mkinitrd source pinned to commit `f825813f356bc52925d9654c7b9ad65b15f0fda7` |
| Boot and ISO | GRUB 2.14, libburn 1.5.8, libisofs 1.5.8.pl02, libisoburn 1.5.8.pl02, M4 1.4.20, Bison 3.8.2, Flex 2.6.4, pkgconf 2.3.0 |
| Not currently installed | Perl 5.44.0 and perl-cross 1.6.5; recipe is failing and Perl is excluded |

Rebuilding the ISO also generates manuals using the Python packages in
`mk/manpages-requirements.txt`. For a fully disconnected ISO build, retain
those Python distributions in a local wheelhouse or retain the generated
manuals/build environment too. A fresh checkout or missing source archive
cannot be fetched offline.

The detailed dependency analysis and current kernel/LLVM blockers are in
[`REBUILD_DEPENDENCIES.md`](REBUILD_DEPENDENCIES.md). That file describes
build requirements; its presence does not mean the rebuild checklist above
has passed.

## Services

BusyBox `init` supervises services from `/etc/inittab`. Lilith is a POSIX `sh`
tool that enables, disables, adds, lists, and removes its marked service
entries; it has no daemon of its own.

```sh
lilith add "sshd -D -e" ssh
lilith list
lilith start ssh
lilith stop ssh
lilith remove ssh
```

Changes made in the live initramfs are in memory and do not persist across
reboots. Add persistent entries to the build's `INITTAB` definition or
`EXTRA_SERVICES`, then regenerate the root filesystem. Managed services must
run in the foreground because BusyBox init restarts them if they exit.

## Current design

- **C and musl first:** Clang/LLD target `x86_64-linux-musl`; the intended
  runtime does not depend on glibc.
- **Small init and service model:** BusyBox init with Lilith; optional
  services are disabled unless configured.
- **Encrypted installation:** the current installer supports LUKS2 root only.
- **Offline goal, not a claim:** source archives and dependencies must be
  available locally, and clean installed-system rebuilds still need to pass
  the checklist.

For project status, use the rebuild checklist and the source/build rules as
the evidence. Items not listed in the Minimal inventory—including X11,
OpenSSH, Wi-Fi daemons, and the extra development applications previously
suggested—are not part of the current Minimal profile.

## Update ownership

The system package manager owns system-wide packages and updates, including
Clang, musl, and the kernel. Ark remains a separate user-local package manager;
it never updates or replaces files under the system root.
