# SimpleLinux

![Project Logo](Logo.png)

> **WORK IN PROGRESS**

SimpleLinux (SL) is a minimal, developer-first Linux distribution built from source, using the **Linux kernel, musl libc, LLVM/Clang, and BusyBox**.

The goal is to provide a lightweight, customizable, offline-ready Linux environment with a simple build system, a curated collection of tools, and its own source-based package manager, [Ark](https://github.com/KrzysztofMarciniak/Ark).

SimpleLinux has three planned profiles:

- **Bare** — the essentials: Linux, musl, and BusyBox.
- **Minimal** — a lightweight C development and system-maintenance environment designed to support rebuilding the base system and working offline.
- **Minimal + X11** — Minimal extended with a lightweight graphical environment, networking tools, and additional applications. Designed to be customized by the user.

The project is under active development. Profiles and package availability may change as components are ported, built, and tested. The package lists below describe intended contents, not necessarily the current state of every build.

## Building

Build the ISO and its required components:

```sh
make
```

Rebuild the root filesystem and regenerate the initramfs and ISO after changing the root filesystem configuration, `inittab`, or related Makefile rules:

```sh
make rootfs
```

Remove build output and generated ISO files while preserving downloaded source archives:

```sh
make clean
```

Boot the ISO using QEMU:

```sh
./run_qemu.sh
```

## Preinstalled programs

The following lists describe the intended contents of each profile. Not every package is necessarily integrated yet.

### Bare

The minimum bootable system:

- Linux kernel
- musl libc
- BusyBox

### Minimal

**Goals:** Rebuild the base system, develop primarily in C, and perform lightweight web access from the command line.

## User

- Creates a default user with a randomly generated hexadecimal username (e.g., `0x00`).
- Sets the hostname to a randomly selected name from a predefined list (e.g., `arctic`, `tundra`, `greenland`, `borealis`, `glacier`, `everest`, `alps`, `denali`, `atlas`, `iceland`, `archipelago`, `boreal`).
- Places a `run-me.sh` script in the user's home directory. The script documents how to rebuild each installed program from source, including musl libc, LLVM/Clang, the Linux kernel, BusyBox, and other available packages.

## Packages

- Linux kernel, musl libc, and BusyBox build support
- Manual pages
- [Ark](https://github.com/KrzysztofMarciniak/Ark) — source-based package manager
- LLVM/Clang — C compiler and selected development tools
- `pkg-config` — library discovery and build flags
- GNU Make — build automation
- OpenSSL — cryptographic libraries and TLS tools
- CA certificate bundle — HTTPS certificate verification
- `binutils` — assembler, linker, and binary utilities
- `bison` — parser generator
- `flex` — lexical analyzer generator
- `bc` — command-line calculator
- `patch` — source patching
- `diffutils` — file comparison utilities

### Minimal + X11

Minimal, extended with a lightweight graphical environment and additional applications. The goal is to provide a functional graphical workstation while allowing users to choose which additional tools they need.

#### Graphical environment

- X11 — graphical display system, runtime components, and development files
- [MWM](https://github.com/KrzysztofMarciniak/minimal-window-manager) — minimal window manager
- [st](https://st.suckless.org/) — simple terminal emulator
- [dmenu](https://tools.suckless.org/dmenu/) — application launcher
- [img](https://github.com/KrzysztofMarciniak/img) — image viewer
- [redact](https://github.com/KrzysztofMarciniak/redact)
- [screenc](https://github.com/KrzysztofMarciniak/screenc)

#### Networking

- OpenSSH — secure remote access, including the SSH client and optional server support

#### Additional software

Databases, additional programming languages, and other developer tools may be installed as needed. The intention is to keep the base system small rather than bundle every possible application into the default installation.

## Design goals

- **KISS** — keep the base system small and avoid unnecessary dependencies.
- **Offline readiness** — support development and package builds using locally available source archives and dependencies.
- **Developer-first** — provide a practical C development environment with LLVM/Clang and essential build tools.
- **Customizability** — allow users to extend the system without requiring a separate distribution profile for every use case.

## Package management

SimpleLinux uses [Ark](https://github.com/KrzysztofMarciniak/Ark), a source-based package manager developed for the project.

The intended approach is to manage software through source builds, keeping the system customizable and making it possible to inspect and modify the software being installed.

Package availability, dependency handling, and offline build capabilities are under development and may vary by package.

## Development status

SimpleLinux is a work in progress. The profiles and package lists describe the intended direction of the project rather than a guarantee that every component is already available.

Current development focuses on building and integrating the base system, maintaining the root filesystem, generating bootable images, and expanding package support.

Contributions, testing, and feedback are welcome.
