# Minimal self-rebuild dependencies

This is an inventory of what the installed Minimal system needs to rebuild the
kernel, musl, LLVM/Clang, and bootloader using the repository's current
configuration. It also separates the extra inputs needed to fetch sources or
recreate the ISO.
The inventory describes the inspected staged rootfs; package and configuration
changes can make it stale.

## Scope and short answer

The pinned components are Linux 6.18.59 for x86_64 with `LLVM=1`, musl 1.2.6,
and LLVM/Clang 21.1.8 targeting `x86_64-linux-musl`. The LLVM configuration
builds Clang, LLD, and compiler-rt while disabling tests and optional zlib,
zstd, libxml2, and terminfo support.

The staged rootfs has the Clang toolchain, GNU Make, and several useful BusyBox
applets, but it is **not yet sufficient to rebuild all three components**.
The most important gaps are CMake and Python for LLVM; libelf development
files for the kernel; Meson and Ninja for kmod; and the
`llvm-readelf` executable expected by Kbuild. Offline rebuilding additionally
requires the source archives to be retained in the checkout's `downloads/`
directory.

`make minimal` builds the Minimal profile ISO and its components; it is not a
kernel/musl/LLVM-only build target. Recreating that ISO has further requirements
listed below.

The Minimal ISO also generates the upstream kernel, LLVM, and Clang manuals
from their pinned source archives. This step uses host Python 3 and installs
Sphinx 7.2.6, Docutils 0.20.1, Myst Parser 2.0.0, and PyYAML 6.0.2 into
`build/` with pip. The ISO includes the `man` reader and pages for the kernel,
installed LLVM/Clang tools, Python, GNU Make, scan-build, and Cryptsetup. The
mandoc source archive is `mandoc-1.14.6.tar.gz`; the kernel's syscall API man
pages are maintained separately in the upstream man-pages project. Mandoc
requires zlib to read compressed manuals, so zlib 1.3.2 is cross-built and its
shared library is staged into the ISO.

OpenSSL 3.5.9 is also cross-built for musl and staged with its CLI, shared
libraries, and headers. A pinned Mozilla CA bundle is installed at
`/etc/ssl/cert.pem` for BusyBox wget's verified OpenSSL TLS helper.

### GRUB and ISO generation

The ISO build source-builds native GRUB 2.14 tools and xorriso 1.5.8 for the
build host. GRUB is configured separately for `i386-pc` and `x86_64-efi`, so
`grub-mkrescue` can produce an ISO that boots on BIOS and UEFI systems. The
Minimal target also receives GRUB utilities and modules for both platforms,
plus a musl-target xorriso stack.

The xorriso stack is libburn 1.5.8, libisofs 1.5.8.pl02, and libisoburn
1.5.8.pl02. Readline, ACL, and zlib integrations are disabled to avoid
additional runtime libraries. GRUB NLS, device-mapper integration, and font
generation are disabled. The boot menu outputs to VGA and the 115200-baud
serial console, and boot entries require PBKDF2 authentication.

The Minimal target also receives M4 1.4.20, Bison 3.8.2, Flex 2.6.4, and
pkgconf 2.3.0 (`pkg-config`) so GRUB and its xorriso dependencies can be
rebuilt there. The initial host build still needs host Bison and Flex for
generated sources, host `pkg-config`, and Meson 0.61 or newer plus Ninja for
the kmod build. These are build-host tools, not target binaries. The kmod
recipe uses its upstream Meson build and disables optional compression and
signature libraries, so kmod does not add target dependencies on zlib, xz,
zstd, or OpenSSL.

Cryptsetup 2.8.8 is cross-built with LUKS1/LUKS2 support. Its target libraries
include device-mapper from LVM2 2.03.43, libuuid/libblkid from util-linux
2.42.4, json-c 0.19, popt 1.19, and the staged OpenSSL. The cryptsetup release
uses its bundled SSE-optimized Argon2 implementation. The kernel config enables
device mapper, dm-crypt, and kernel keys. The Minimal profile stages the kernel
modules, kmod tools, and BusyBox-based mkinitrd generator, whose optional
cryptsetup hook can unlock a separate encrypted root. The ISO still boots its
complete rootfs from the existing generated initramfs; that hook is not enabled
for the ISO boot path. Building cryptsetup requires host `pkg-config` for its
target-only dependency checks.

## Component requirements

### Linux kernel and installed headers

For the current x86_64 configuration, the build needs:

- GNU Make 4.x and the Clang/LLVM tools selected by `LLVM=1`: `clang`,
  `clang++`, `ld.lld`, `llvm-ar`, `llvm-nm`, `llvm-strip`, `llvm-objcopy`,
  `llvm-objdump`, and `llvm-readelf`. LLVM mode substitutes these for the
  corresponding GNU binutils tools.
- Perl, Flex, and Bison for kernel build scripts and Kconfig. The project
  edits its selected kernel config with POSIX shell and `sed`, avoiding the
  upstream Bash-based `scripts/config` helper. The project's configuration
  also uses `bc`; the BusyBox `bc` applet is present.
- Perl 5.44.0 now has a Minimal-profile cross-build rule. It uses
  perl-cross 1.6.5 to build its temporary host-side `miniperl` bootstrap and
  the installed musl-target interpreter. Its `install` target also installs
  Perl's upstream POD manuals into `/usr/share/man/man1` and `man3`, where the
  Minimal `mandoc` reader can find them. It does not require or install a
  separate host Perl.
- libelf development files (`libelf.h` and the linkable `libelf` library).
  The current config enables the x86 ORC unwinder, and the x86 `objtool`
  build links with libelf. A runtime-only libelf library is not enough.
- `pkg-config` for the kernel's documented Kconfig/tool checks and graphical
  Kconfig frontends. The repository currently generates configuration with
  `defconfig`/`olddefconfig`, rather than the graphical frontends.

Python is needed by some kernel configurations and helper scripts, so it should
be included for broader kernel build support. `pahole` is needed when building
BTF debug information, and OpenSSL plus development libraries are needed when
module signing is enabled. The inspected kernel configuration disables BTF,
module signing, debug info, and Clang LTO, so those feature-specific tools are
not unconditional requirements for this build.

The inspected rootfs has most LLVM tools and a `readelf` entry, but not the
`llvm-readelf` name Kbuild expects. The toolchain Make rule creates `readelf`
as a link to `llvm-readelf`; verify that the latter exists in the installed
image before relying on `LLVM=1`.

The repository's musl build also builds and installs kernel headers first.
That is a project-pipeline dependency, beyond musl's own compiler and Make
requirements.

### musl

musl's documented build prerequisites are GNU Make and a freestanding C99
compiler. In this project, the installed Clang toolchain provides the compiler
targeting `x86_64-linux-musl`, and the repository builds kernel headers before
musl. No OpenSSL, CMake, or Python dependency is introduced by the musl build
itself.

### LLVM/Clang

The configured LLVM build needs:

- CMake 3.20 or newer and a Python 3 interpreter.
- GNU Make, since the repository uses CMake's Unix Makefiles generator.
- A working C and C++ bootstrap compiler. For a self-rebuild, the installed
  `cc`/`c++` and `clang`/`clang++` point to the existing Clang toolchain.
- The staged C++ runtime and headers used by this build, including libc++,
  libc++abi, and libunwind.

LLVM's source sets a lower Python floor when tests are disabled, as they are
here, but LLVM's Getting Started documentation gives a newer Python baseline.
Use Python 3.8 or newer to avoid relying on that configuration-specific floor.
Ninja, test runners, and the optional libraries listed above are not required
by the current CMake arguments.

#### Can Python be removed?

There is no supported CMake switch to remove Python from this LLVM 21.1.8
build. `llvm/CMakeLists.txt` calls `find_package(Python3 ... REQUIRED)`
unconditionally; disabling tests only lowers LLVM's requested minimum version
and does not make the interpreter optional. The configure step also invokes
Python to probe optional modules in `llvm/cmake/config-ix.cmake`.

Python is used by the normal Clang build as well: the FlowSensitive analysis
library depends on `HTMLLogger.inc`, generated by
`clang/utils/bundle_resources.py`. Disabling tests and documentation does not
disable that library or its resource-generation step.

Removing Python entirely would therefore require maintaining an LLVM source
patch: make the top-level interpreter lookup optional, replace or pre-generate
the FlowSensitive resource file, and audit the selected projects for other
Python commands. This is not a one-flag change and would need a clean
configure/build test with Python unavailable. The practical alternative is to
provide Python only in the build environment and omit it from the installed
rootfs; that does not support rebuilding from the installed system unless the
build environment is supplied again.

## What is in the inspected Minimal rootfs

| Requirement | Status | Notes |
|---|---|---|
| Clang/Clang++, LLD, compiler-rt, libc++ runtime | Present | Supplies the bootstrap compiler and target toolchain. |
| GNU Make 4.4.1 | Present | Also satisfies the project Make recipes. |
| `llvm-ar`, `llvm-nm`, `llvm-strip`, `llvm-objcopy`, `llvm-objdump` | Present | Required LLVM-mode tools. |
| `llvm-readelf` | Missing | `readelf` is present, but Kbuild's `LLVM=1` mapping expects `llvm-readelf`. |
| BusyBox `bc`, tar, gzip, bzip2, xz, `diff`, `patch` | Present | Useful for kernel scripts and unpacking sources. |
| BusyBox `wget` | Present | Does not replace the repository's `curl` download rule. |
| CMake 3.20+ and Python 3 | Missing | Required for the configured LLVM build. |
| Bash | Not required for the configured build | The project avoids upstream Bash-only helper scripts; optional kernel maintenance targets may still use Bash. |
| Meson 0.61+ and Ninja | Missing | Host build tools for the kmod cross-build; Python 3 is present. |
| M4, Bison, Flex | Source build rules added; unverified | Staged for rebuilding GRUB from the Minimal target. |
| GRUB 2.14 and xorriso 1.5.8 target tools | Source build rules added; unverified | BIOS/UEFI modules and the musl xorriso dependency stack are staged. |
| kmod 34 and Linux kernel modules | Source build rules added; unverified | Cross-built with Meson; optional compression and signature libraries are disabled for the current uncompressed, unsigned kernel modules. |
| mkinitrd | Source pinned and staged; unverified | Runtime generator for a separate root filesystem; its optional cryptsetup hook is not used by the current ISO boot path. |
| Mozilla CA certificate bundle | Pinned and staged; unverified | Installed at OpenSSL's default trust path for certificate-verified HTTPS. |
| Perl 5.44.0 and manuals | Build rule added; unverified | Cross-built for musl with perl-cross 1.6.5; the package installs Perl's POD manuals under `/usr/share/man`. Its temporary host `miniperl` is only a build-time bootstrap. |
| libelf headers and development linker library | Missing | Required by x86 `objtool` with the ORC unwinder. |
| `pkg-config` | Source build rule added; unverified | Provided by target pkgconf 2.3.0. |
| Target OpenSSL CLI | Missing in the inspected rootfs | The Minimal build now stages a musl OpenSSL CLI and libraries; it also supplies BusyBox's external `openssl s_client` runtime. |
| curl | Missing | The repository source-download rule invokes `curl`. |
| CA certificate bundle | Source added; unverified | Needed for BusyBox wget's verified external OpenSSL TLS helper. |

The rootfs Make recipe uses the **host** OpenSSL CLI to create shadow password
hashes. It cannot run the musl-target OpenSSL binary being staged into the ISO;
the host command remains an independent build prerequisite.

The BusyBox HTTPS configuration also enables `FEATURE_WGET_OPENSSL`. That path
uses an external `openssl s_client`; the target OpenSSL package supplies it.
The pinned Mozilla CA bundle is staged at OpenSSL's default certificate path,
`/etc/ssl/cert.pem`, so HTTPS peer verification can succeed.

## Offline source inputs and other build steps

The source rules in `mk/sources.mk` download archives with `curl` and unpack
them under `build/src`. To rebuild without network access, keep the exact
archives in the checkout's `downloads/` directory:

- `linux-6.18.59.tar.xz`
- `musl-1.2.6.tar.gz`
- `llvm-project-21.1.8.src.tar.xz`
- `mandoc-1.14.6.tar.gz`
- `zlib-1.3.2.tar.gz`
- `openssl-3.5.9.tar.gz`
- `perl-5.44.0.tar.gz`
- `perl-cross-1.6.5.tar.gz`
- `cryptsetup-2.8.8.tar.xz`
- `LVM2.2.03.43.tgz`
- `popt-1.19.tar.gz`
- `json-c-0.19.tar.gz`
- `util-linux-2.42.4.tar.xz`
- `kmod-34.tar.xz`
- `f825813f356bc52925d9654c7b9ad65b15f0fda7.tar.gz` (mkinitrd)
- `cacert-2026-10-20.pem`
- `grub-2.14.tar.xz`
- `libburn-1.5.8.tar.gz`
- `libisofs-1.5.8.pl02.tar.gz`
- `libisoburn-1.5.8.pl02.tar.gz`
- `m4-1.4.20.tar.xz`
- `bison-3.8.2.tar.xz`
- `flex-2.6.4.tar.gz`
- `pkgconf-2.3.0.tar.xz`

Rebuilding the full Minimal profile also needs the BusyBox, GNU Make, and Ark
archives referenced by `mk/sources.mk`. The inspected host has these archives
in its build cache, but the staged rootfs does not include that cache. Copying
the archives into an installed system's checkout is therefore a separate
offline setup step. The included BusyBox tar and compression applets can unpack
the current archive formats.

Fetching uncached sources from the installed system requires adding `curl` or
changing the repository's download rule. BusyBox `wget` is present but is not
called by that rule. Its external OpenSSL client is supplied by the Minimal
OpenSSL package; authenticated connections still need a CA bundle.

Finally, rebuilding the bootable ISO is distinct from compiling the three
components. The image rules build native `grub-mkrescue` and xorriso from the
pinned sources described above. Rootfs regeneration invokes the OpenSSL
password-hash command described above. These are additional requirements for
the complete `make minimal` workflow, not prerequisites of the kernel, musl,
or LLVM compilers themselves.

## Source references

- Repository build flow and source handling: `mk/profiles.mk`, `mk/kernel.mk`,
  `mk/userland.mk`, `mk/toolchain.mk`, `mk/llvm-runtime.mk`, `mk/sources.mk`,
  `mk/rootfs.mk`, and `mk/image.mk`.
- Versions and target: `config.mk`; kernel feature settings:
  `build/linux-out/.config`.
- Kernel build requirements and LLVM tool mapping:
  `build/src/linux-6.18.59/Documentation/process/changes.rst` and
  `build/src/linux-6.18.59/Documentation/kbuild/llvm.rst`.
- x86 `objtool`'s libelf link: `build/src/linux-6.18.59/tools/objtool/Makefile`.
- musl build prerequisites: `build/src/musl-1.2.6/INSTALL`.
- LLVM's CMake/Python requirements:
  `build/src/llvm-project-21.1.8.src/llvm/CMakeLists.txt`,
  `build/src/llvm-project-21.1.8.src/llvm/cmake/config-ix.cmake`, and
  `build/src/llvm-project-21.1.8.src/clang/lib/Analysis/FlowSensitive/CMakeLists.txt`.
- BusyBox applet and HTTPS configuration: `busybox.config`; HTTPS behavior:
  `build/src/busybox-1.38.0/networking/wget.c`.
- Perl cross-build integration: `mk/perl.mk`, `mk/sources.mk`, and the
  perl-cross 1.6.5 release, which explicitly supports Perl 5.44.0.
- LUKS tools and kernel configuration: `mk/luks.mk`, `mk/kernel.mk`, and
  `mk/sources.mk`.
- kmod's Meson build and options: `mk/mkinitrd.mk`,
  `build/src/kmod-34/meson.build`, and `build/src/kmod-34/meson_options.txt`.
