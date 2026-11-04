# How to Add a New Part to the Build

This guide explains how the Makefiles in this repository fit together and how
to add a component without making it an accidental one-off shell script.

## The short version

The top-level `Makefile` sets shared paths and toolchain variables, then includes
the fragments in `mk/`. Targets depend on files and stamp files, so GNU Make
uses the dependency graph to decide what to download, build, install, or put in
the ISO. Component recipes belong in their own `mk/<component>.mk` file.

The usual flow is:

```text
source URL
   -> downloads/<archive>
   -> build/stamps/<name>.unpacked
   -> build/stamps/<name>.built
   -> build/stamps/<name>.rootfs
   -> build/initramfs.gz
   -> SimpleLinux-0.1.iso
```

Not every component uses every stage. A host-only tool may stop at `.built`;
kernel headers and toolchains have their own stages; some packages install
directly into the root filesystem.

## File map

| File | Purpose |
| --- | --- |
| `Makefile` | Default goal, shared build directories, profile selection, target compiler variables, and includes all build fragments. |
| `config.mk` | Project-wide versions, target architecture, parallelism, and cache defaults. |
| `mk/sources.mk` | Source archive URLs, source-directory names, and the shared download/unpack rule. |
| `mk/profiles.mk` | `bare` and `minimal` convenience targets and the saved profile stamp. |
| `mk/kernel.mk` | Kernel headers exported to the sysroot and the kernel image build. |
| `mk/llvm-runtime.mk`, `mk/toolchain.mk` | LLVM runtime bootstrap, then the staged Clang/LLD toolchain. |
| `mk/userland.mk`, `mk/busybox.mk` | musl, the target compiler wrapper, Ark, and BusyBox. |
| `mk/rootfs.mk` | Base root filesystem configuration and minimal-profile accounts/services. |
| `mk/image.mk` | Initramfs generation and ISO assembly; also connects minimal-only package stamps to the image. |
| Other `mk/*.mk` files | Component-specific build, install, and rootfs rules. |

Make fragments are included by the top-level `Makefile`; they are not
standalone Makefiles. They rely on shared variables and rules defined by the
top-level file and other fragments.

## Invoking the build and choosing a profile

The default goal is `iso`. The supported profiles are `bare` and `minimal`:

```sh
make bare
make minimal
make PROFILE=minimal iso
make PROFILE=minimal perl
```

`bare` and `minimal` are convenience targets that recursively invoke `iso`
with the corresponding `PROFILE`. If `PROFILE` is omitted, the top-level
Makefile reuses `build/stamps/profile` when it exists; otherwise it defaults to
`bare`. The profile stamp is updated only when the selected profile changes.

Some package aliases, such as `perl`, are defined only for `PROFILE=minimal`.
The ISO is the final product; a package alias is useful for building/installing
one component without requesting the ISO.

The main build controls are:

- `JOBS` controls ordinary parallel builds and defaults to `nproc`.
- `KERNEL_JOBS` controls the kernel build and defaults to `JOBS`.
- `TARGET_CCACHE`, `LLVM_CCACHE_BUILD`, and `BUSYBOX_CCACHE` control caching
  for the corresponding build stages. `CCACHE_ENABLED` detects whether the
  configured `CCACHE` command is available.
- `MIN_USER`, `MIN_UID`, `MIN_GID`, `MIN_HOSTNAME`, `ROOT_PASSWD`, and
  `USER_PASS` control minimal-profile account settings.

## Where files go

The top-level Makefile defines the shared paths. Keep generated files under
these paths rather than in the source tree:

| Variable | Path | Contents |
| --- | --- | --- |
| `DL` | `downloads/` | Downloaded source archives. |
| `B` | `build/` | All build products and staging areas. |
| `SRC` | `build/src/` | Extracted upstream source trees. |
| `STAMP` | `build/stamps/` | Completion/configuration stamps used by Make. |
| `SYSROOT` | `build/sysroot/` | Target headers, libraries, and metadata used to compile for musl. |
| `ROOTFS` | `build/rootfs/` | The assembled target filesystem copied into the initramfs. |
| `KOUT` | `build/linux-out/` | Out-of-tree Linux kernel build. |
| `INITRD` | `build/initramfs.gz` | Generated initramfs. |
| `ISO` | `SimpleLinux-0.1.iso` | Final ISO image. |

Packages commonly use their own `$(B)/<name>-build` and
`$(B)/<name>-install` directories. The install directory is a staging area;
install with `DESTDIR=$(abspath $(NAME_INST))`, then copy its `usr/` tree into
`$(ROOTFS)/usr/`.

## How downloads and stamps work

`mk/sources.mk` defines a `PKG` Make macro. Given a package name and URL, it
creates two rules:

1. Download the archive into `$(DL)`, first writing to a `.part` file and then
   renaming it after the download succeeds.
2. Extract it under `$(SRC)` and touch `$(STAMP)/<name>.unpacked`.

For example, the existing declarations look like:

```make
$(eval $(call PKG,perl,$(PERL_URL)))
PERL_SRC := $(SRC)/perl-$(PERL_VERSION)
```

A stamp is a normal file used as a Make target. A target such as
`$(STAMP)/foo.built` is considered complete while that file is newer than its
prerequisites. Component recipes should touch the stamp **last**, after the
build, install, and sanity checks succeed. A failed recipe must not leave a
success-looking stamp.

Make only notices inputs listed as prerequisites. If a build depends on a
config file, helper script, source patch, or Make fragment, list it as a
prerequisite. Most component rules list their own `mk/<component>.mk` and
`config.mk` so edits invalidate the relevant stamp.

Some settings are tracked by small stamp files with a `FORCE` prerequisite.
For example, `target.ccache`, `busybox.ccache`, and `llvm.config` compare the
current setting to the saved value and rewrite the stamp only when it changes.
This makes Make re-run the affected build when the setting changes without
rebuilding it on every invocation.

## Host tools, target tools, and the sysroot

There are two kinds of executables in these recipes:

- **Host tools** run during the build, such as CMake, shell scripts, code
  generators, and build-time Python. They use the host environment/compiler.
- **Target programs and libraries** run in SimpleLinux. They must be compiled
  for `$(TARGET)` and against `$(SYSROOT)`.

The staged LLVM toolchain is installed under `$(LLVM_INST)`. The common target
compiler command is:

```make
CC_SYS = $(abspath $(LLVM_INST))/usr/bin/clang \
         --target=x86_64-linux-musl \
         --sysroot=$(abspath $(SYSROOT)) \
         -rtlib=compiler-rt -unwindlib=none
```

`CC_SYS_CACHED` prepends the configured ccache command when
`TARGET_CCACHE=ON`. Linker flags commonly add `-fuse-ld=lld`,
`-B$(abspath $(LLVM_INST))/usr/bin`, and the appropriate compiler runtime
options.

Some configure scripts cannot correctly handle `CC` as a multiword command
because they quote, split, or reparse it. `mk/userland.mk` creates
`$(CC_WRAP)` (`build/cc-sys`), a single executable that forwards to the target
compiler with the required flags. Reuse that wrapper for configure scripts
that need one executable path; `mk/perl.mk` is an example. Do not assume adding
the LLVM bin directory to `PATH` is enough: cross-configure scripts may require
tools such as `NM`, `READELF`, or `OBJDUMP` to be set explicitly.

`mk/kernel.mk` exports Linux headers into `$(SYSROOT)/usr` before musl is
built. Packages that need target dependencies should use `$(SYSROOT)` and
target-specific `PKG_CONFIG_LIBDIR`/`PKG_CONFIG_SYSROOT_DIR` values so they do
not accidentally find host headers or libraries.

The LLVM build is staged in two parts: `mk/llvm-runtime.mk` builds the target
runtimes with host tools, then `mk/toolchain.mk` builds and installs the
Clang/LLD toolchain using those runtimes. `mk/python.mk` similarly builds a
host Python interpreter for build-time generators before cross-building the
Python installed in the minimal image.

## Adding a new source-built component

### 1. Add the source archive

Define the version and URL near the other source definitions in
`mk/sources.mk`, define the extracted directory, and instantiate `PKG`:

```make
FOO_VERSION := 1.2.3
FOO_URL := https://example.invalid/foo-$(FOO_VERSION).tar.gz
FOO_SRC := $(SRC)/foo-$(FOO_VERSION)

$(eval $(call PKG,foo,$(FOO_URL)))
```

Use the archive's actual top-level directory when defining `FOO_SRC`. The
shared macro handles downloading and extraction; it does not apply patches or
configure the package.

### 2. Add a component fragment

Create `mk/foo.mk` and include it from the top-level `Makefile`. Define separate
build and staging directories. A typical minimal-profile package has:

```make
FOO_BUILD := $(B)/foo-build
FOO_INST  := $(B)/foo-install

.PHONY: foo
ifeq ($(PROFILE),minimal)
foo: $(STAMP)/foo.rootfs

$(STAMP)/foo.built: $(STAMP)/foo.unpacked $(STAMP)/musl.built \
                    $(STAMP)/llvm.built $(STAMP)/target.ccache \
                    $(CC_WRAP) $(CURDIR)/mk/foo.mk $(CURDIR)/config.mk
	rm -rf $(FOO_BUILD) $(FOO_INST)
	mkdir -p $(FOO_BUILD)
	# Configure for $(TARGET), using $(SYSROOT) and the target compiler.
	# Build with $(MAKE) -C $(FOO_BUILD) -j$(JOBS).
	# Install with DESTDIR=$(abspath $(FOO_INST)).
	test -x $(FOO_INST)/usr/bin/foo
	@touch $@

$(STAMP)/foo.rootfs: $(STAMP)/foo.built $(STAMP)/rootfs.done \
                     $(CURDIR)/mk/foo.mk
	mkdir -p $(ROOTFS)/usr
	cp -a $(FOO_INST)/usr/. $(ROOTFS)/usr/
	@touch $@
endif
```

Replace the comments with the package's real configure/build/install commands
and checks. Only list prerequisites the build actually needs:

- `foo.unpacked` for the extracted source.
- `musl.built`, `llvm.built`, or other package stamps for actual dependencies.
- `target.ccache` if the recipe uses `CC_SYS_CACHED`.
- `$(CC_WRAP)` if the package's configure system needs a single-file target
  compiler wrapper.
- Local Make fragments, configuration files, and patches that affect output.

Use `$(MAKE)` for recursive Make invocations so GNU Make can pass its jobserver
and flags to the sub-build. Keep recipes tab-indented. Validate installed
artifacts with focused `test -x`, `test -f`, or `test -e` checks before touching
the stamp.

### 3. Connect it to the profile and image

The component's `foo` phony target is for explicit requests. To include the
component automatically in the minimal ISO, add its rootfs stamp as an
`$(INITRD)` prerequisite in the minimal section of `mk/image.mk`:

```make
ifeq ($(PROFILE),minimal)
$(INITRD): $(STAMP)/foo.rootfs
endif
```

Without this dependency, the ISO graph has no reason to build the package.
Packages that are build-time-only do not need a `.rootfs` stage or this image
dependency; make their `.built` stamp a prerequisite of the component that
uses them instead.

If adding a package changes base account setup, init scripts, or common rootfs
configuration, update `mk/rootfs.mk`. For package files, keep package-specific
copy/install rules in the package fragment and depend on `$(STAMP)/rootfs.done`.

### 4. Include the fragment

Add the fragment once to the include list in `Makefile`, near related
components. Shared variables such as `B`, `STAMP`, `SYSROOT`, `ROOTFS`,
`INITRD`, `CC_SYS`, and `CC_WRAP` are defined by the top-level file or other
included fragments.

## Dependency graph and the current build stages

GNU Make does not follow the order of include files to determine build order;
the prerequisites define the graph. The current build roughly has these
relationships:

- Kernel source is unpacked once. `headers.built` installs kernel headers into
  the target sysroot; `kernel.built` configures and builds the bootable kernel
  into `KOUT`.
- LLVM source feeds the runtime bootstrap and staged compiler toolchain.
- musl depends on installed kernel headers. Other target components depend on
  musl, the target compiler, and any target libraries they need.
- BusyBox installs the base userland into `ROOTFS`; `rootfs.done` writes the
  profile-specific filesystem configuration.
- Minimal-only packages have `.rootfs` stamps that copy staged installations
  into `ROOTFS`. The minimal dependencies in `mk/image.mk` make those stages
  complete before initramfs creation.
- `INITRD` is generated from files, directories, symlinks, and device nodes in
  `ROOTFS`. The final `ISO` target copies the kernel and initramfs into a GRUB
  tree and invokes `grub-mkrescue`.

`mk/luks.mk` is a useful example of a dependency subgraph: it builds target
libraries, combines them into a private sysroot, then builds cryptsetup against
that sysroot before installing the result into the root filesystem.

## Editing and rebuilding safely

- Keep each component's variables and recipes in its own `mk/*.mk` fragment.
- Keep shared versions/architecture/cache defaults in `config.mk`; keep source
  archive URLs and `PKG` declarations in `mk/sources.mk`.
- Put profile-specific targets behind `ifeq ($(PROFILE),minimal)` where
  appropriate. Do not make a bare profile depend on a minimal-only package.
- Make dependencies explicit. A comment saying one package needs another does
  not create an ordering constraint; a stamp prerequisite does.
- Prefer a staging install (`DESTDIR=$(..._INST)`) followed by a `.rootfs`
  copy. This keeps target installation separate from the host and makes the
  rootfs dependency visible.
- Do not touch a success stamp before all commands and checks have succeeded.
- `clean` removes the entire `build/` tree and the ISO. It is a full clean, not
  a targeted component rebuild.
- The `rootfs` target invalidates the rootfs stamp, initramfs, and ISO, then
  requests the ISO again. It does not erase every component build.
- When a build does not rerun after an input edit, check whether that input is
  a prerequisite of the relevant `.built`/`.rootfs` stamp.

For a new part, verify both paths: request its component target directly, then
confirm the profile's image target depends on its rootfs stamp. Build/test
commands are intentionally left to the person running the build; the Makefile
rules are the source of truth for the commands each target executes.
