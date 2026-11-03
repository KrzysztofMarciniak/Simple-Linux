# How the LLVM/Clang toolchain is built

This document describes the two LLVM build stages in this repository, why
CMake's compiler check failed with a missing `libclang_rt.builtins.a`, why the
shared-library link failed without PIC objects, how the flags fit together,
and what to check before starting a long build.
The instructions assume commands are run from the repository root.

## The build at a glance

There are three different toolchains/targets involved. Keep them distinct:

| Name | What it is | Where it comes from |
|---|---|---|
| Host compiler | Runs on the machine doing the build and compiles LLVM itself | `cc`, `c++`, and `/usr/bin/clang` from the host |
| Staged runtimes | compiler-rt, libc++, libc++abi, and libunwind built for this project | `build/llvm-runtime-install/usr` |
| New toolchain | LLVM/Clang 21 built for the host, configured to default to the project's musl target | `build/llvm-install/usr` and then `build/rootfs/usr` |

`TARGET` in `config.mk` is `x86_64-linux-musl`. The host in the reported
failure is Alpine Linux, whose `/usr/bin/clang` reports the host target
`x86_64-alpine-linux-musl`. Setting `LLVM_DEFAULT_TARGET_TRIPLE=$(TARGET)`
configures the Clang being built to default to the project target; it does not
change the host target or resource directory of `/usr/bin/clang` while that
host compiler builds LLVM.

The relevant Make targets and directories are:

| Make target/stamp | Purpose | Build/install directories |
|---|---|---|
| `build/stamps/llvm.unpacked` | Unpack LLVM sources | `build/src/llvm-project-21.1.8.src` |
| `build/stamps/llvm.runtime` | Build and install the runtimes | `build/llvm-runtime-build`, `build/llvm-runtime-install`; rule in `mk/llvm-runtime.mk` |
| `build/stamps/llvm.built` | Build and install LLVM/Clang | `build/llvm-build`, `build/llvm-install` |
| `build/stamps/llvm.rootfs` | Copy the installed toolchain into the root filesystem | `build/rootfs` |

The default `LLVM_VERSION` is `21.1.8`; its Clang resource directory uses the
major version, `21`.

## Stage 1: build the runtimes

The `llvm.runtime` rule in `mk/toolchain.mk` configures the LLVM source tree
with the host `cc` and `c++`, and enables these runtime projects:

```text
compiler-rt;libcxx;libcxxabi;libunwind
```

It installs them with `DESTDIR=build/llvm-runtime-install`. The configured
install prefix is `/usr`, so the staged files appear beneath
`build/llvm-runtime-install/usr`. In particular, compiler-rt's builtins
archive is expected beneath:

```text
build/llvm-runtime-install/usr/lib/clang/21/lib/linux/
```

The rule then copies Clang's builtin headers into
`build/llvm-runtime-install/usr/lib/clang/21/include`. This makes the staged
resource directory usable by Clang for both compiler-provided headers and
compiler runtime files.

The runtime stage is not the final Clang build. It supplies the C++ standard
library, ABI library, unwinder, and compiler builtins that the next stage
links against.

## Stage 2: build LLVM/Clang

The `llvm.built` rule configures LLVM with `clang` and `clang++`. In this
environment those names resolve to the host Clang (the error showed
`/usr/bin/clang`, version 22), not to the LLVM 21 compiler that is being
built. LLVM's build tools must run on the host, so using a host compiler here
is intentional.

Before configuring, the rule copies the staged runtime installation into
`build/llvm-install/usr`. It then passes the staged C++ headers and link
settings to CMake. The important settings are:

```make
-DCMAKE_CXX_FLAGS='-nostdinc++ -isystem .../usr/include/c++/v1'
-DCMAKE_CXX_STANDARD_LIBRARIES='-stdlib=libc++'
-DCMAKE_POSITION_INDEPENDENT_CODE=ON
-DCMAKE_EXE_LINKER_FLAGS='$(LLVM_RUNTIME_LINK_FLAGS)'
-DCMAKE_SHARED_LINKER_FLAGS='$(LLVM_RUNTIME_LINK_FLAGS)'
-DCMAKE_MODULE_LINKER_FLAGS='$(LLVM_RUNTIME_LINK_FLAGS)'
```

The linker flags are supplied for executables, shared libraries, and modules
because LLVM builds all three kinds of targets. CMake also uses the executable
link flags for its initial C compiler test.
`CMAKE_POSITION_INDEPENDENT_CODE=ON` ensures static LLVM component libraries
are compiled as PIC because they are linked into `libLLVM.so`.

## What each important flag does

`LLVM_RUNTIME_LINK_FLAGS` in `mk/toolchain.mk` is:

```make
LLVM_RUNTIME_LINK_FLAGS := -resource-dir=$(LLVM_RUNTIME_RESOURCE_DIR) \
  -L$(LLVM_RUNTIME_LIBDIR) \
  -Wl,-rpath-link,$(LLVM_RUNTIME_LIBDIR) \
  -rtlib=compiler-rt -unwindlib=libunwind
```

| Flag | Purpose | What it does not do |
|---|---|---|
| `-resource-dir=.../usr/lib/clang/21` | Tells Clang where this staged LLVM version's resource files live. Clang uses this directory to find builtin headers and compiler runtime files such as compiler-rt's builtins archive. | It does not choose the C++ standard library or the linker. |
| `-rtlib=compiler-rt` | Selects compiler-rt as the compiler runtime instead of GCC's `libgcc`. Clang adds the appropriate builtins archive when linking. | It does not tell the linker to search arbitrary `-L` directories for the builtins archive. |
| `-unwindlib=libunwind` | Selects LLVM libunwind for exception-unwinding support. | It does not select compiler-rt's builtins. |
| `-L$(LLVM_RUNTIME_LIBDIR)` | Adds the staged runtime library directory to the linker's normal `-lfoo` search path. This is needed for libraries such as `libunwind` and the C++ libraries. | It does not override Clang's resource directory or locate compiler-rt builtins by itself. |
| `-Wl,-rpath-link,...` | Passes `-rpath-link` to the linker so it can resolve dependencies of shared libraries while linking. | It does not set a runtime search path in the produced executable. |
| `-nostdinc++` | Prevents host C++ standard-library headers from being mixed into this build. | It does not disable C headers. |
| `-isystem .../include/c++/v1` | Uses the staged libc++ headers as system C++ headers. | It does not link libc++ by itself. |
| `-stdlib=libc++` | Tells Clang to link programs using libc++. | It does not select compiler-rt or libunwind. |

The LLVM build flags `-DCLANG_DEFAULT_RTLIB=compiler-rt` and
`-DCLANG_DEFAULT_UNWINDLIB=none` configure defaults for the Clang being built.
They do not replace the flags needed by the host Clang during LLVM's own
build.

`LLVM_BUILD_ENV` removes environment variables such as `CC`, `CXX`, `CFLAGS`,
`CXXFLAGS`, and `LDFLAGS` before invoking CMake. This prevents a caller's
environment from silently overriding the compilers and flags specified by the
Make rules. If a build depends on an environment override, check this filter
before assuming CMake received that override.

## Why the reported CMake failures occurred

During `project()`, CMake compiles and links a tiny C program to verify
`CMAKE_C_COMPILER`. In the failure log, compilation succeeded; the link step
failed because Clang requested:

```text
/usr/lib/llvm22/lib/clang/22/lib/x86_64-alpine-linux-musl/libclang_rt.builtins.a
```

That is the host Clang 22 resource location. This project had instead built
the LLVM 21 archive under `build/llvm-runtime-install/usr/lib/clang/21`.
Adding the staged `-L` directory was insufficient: Clang chooses the
compiler-rt builtins archive from its resource directory, not from the
linker's ordinary `-L` search path.

The fix is to pass
`-resource-dir=$(LLVM_RUNTIME_RESOURCE_DIR)` alongside
`-rtlib=compiler-rt`. This keeps the intended compiler-rt/libunwind runtime
combination and points the host compiler at the staged LLVM 21 runtime files.
Do not “fix” this by switching to `-rtlib=libgcc`: that changes the runtime
selection and conflicts with `-unwindlib=libunwind` unless both are changed
together.

The later `libLLVM.so` link failure had a separate cause. LLVM's shared
library links static component archives, so those objects must be compiled
with `-fPIC`. In the failed configure, `CXX_SUPPORTS_FPIC` was empty and
`LLVMSupport`'s compile flags contained no `-fPIC`. With
`LLVM_ENABLE_LIBCXX=ON`, LLVM's `HandleLLVMStdlib.cmake` adds
`-stdlib=libc++` to the global C++ compile flags. Alpine's Clang warns that
this option is unused during compile-only compiler-flag checks; because the
PIC check uses `-Werror`, that warning makes the check fail and LLVM does not
add `-fPIC`. The resulting thread-local relocation cannot be linked into
`libLLVM.so`.

The final-stage rule therefore keeps libc++ selection explicit: staged
headers are selected with `-nostdinc++` and `-isystem`, and
`-stdlib=libc++` is supplied through the link-only
`CMAKE_CXX_STANDARD_LIBRARIES` setting. `LLVM_ENABLE_LIBCXX` is OFF so it
does not inject `-stdlib` into compile-only checks. The rule also sets
`CMAKE_POSITION_INDEPENDENT_CODE=ON` to ensure LLVM's static component
libraries are PIC. These settings preserve libc++ while preventing the
non-PIC shared-library link failure.

## Preflight: verify the exact link before starting a build

First verify the host compiler and its defaults:

```sh
/usr/bin/clang --version
/usr/bin/clang -print-resource-dir
/usr/bin/clang -print-target-triple
```

Then verify that the staged compiler-rt archive exists:

```sh
find build/llvm-runtime-install/usr/lib/clang \
  -name 'libclang_rt.builtins*.a' -print
```

For the current LLVM 21 configuration, run a small C link using the same
runtime selection and staged paths as the CMake test:

```sh
set -eu
testbin="$(mktemp /tmp/llvm-c-link-test.XXXXXX)"
trap 'rm -f "$testbin"' EXIT

printf 'int main(void) { return 0; }\n' |
  /usr/bin/clang -x c - \
    -resource-dir="$PWD/build/llvm-runtime-install/usr/lib/clang/21" \
    -L"$PWD/build/llvm-runtime-install/usr/lib" \
    -Wl,-rpath-link,"$PWD/build/llvm-runtime-install/usr/lib" \
    -rtlib=compiler-rt -unwindlib=libunwind \
    -o "$testbin"
```

Also test the staged libc++ headers and libraries with the corresponding C++
settings:

```sh
set -eu
testbin="$(mktemp /tmp/llvm-cxx-link-test.XXXXXX)"
trap 'rm -f "$testbin"' EXIT

printf '#include <string>\nint main() { std::string s = "ok"; return s.size() != 2; }\n' |
  /usr/bin/clang++ -x c++ - \
    -resource-dir="$PWD/build/llvm-runtime-install/usr/lib/clang/21" \
    -nostdinc++ \
    -isystem "$PWD/build/llvm-runtime-install/usr/include/c++/v1" \
    -stdlib=libc++ \
    -L"$PWD/build/llvm-runtime-install/usr/lib" \
    -Wl,-rpath-link,"$PWD/build/llvm-runtime-install/usr/lib" \
    -rtlib=compiler-rt -unwindlib=libunwind \
    -o "$testbin"

LD_LIBRARY_PATH="$PWD/build/llvm-runtime-install/usr/lib" "$testbin"
```

The `21` in these commands is the major version from `LLVM_VERSION`. If that
version changes, use the directory named by `LLVM_RUNTIME_RESOURCE_DIR` in
`mk/toolchain.mk`. Do not start `make minimal` or `make iso` if either smoke
test fails. Fix the specific missing file or flag first.

The `LD_LIBRARY_PATH` line is required to run this standalone test. The link
flags include `-Wl,-rpath-link`, which helps the linker find dependent shared
libraries while linking, but it does not add a runtime search path to the
executable. The staged libc++ is shared, so the dynamic loader must be told
where it lives when running the test.

If the smoke test passes but CMake still fails, inspect the new CMake log and
confirm its test link command contains the same `-resource-dir`,
`-rtlib=compiler-rt`, and `-unwindlib=libunwind` options. Also confirm that
the resource directory in that command is the staged one, not the host
Clang's `-print-resource-dir` result.

## Important: runtime lookup while building LLVM

The resource-directory fix addresses the original CMake C compiler link
failure. It does not, by itself, guarantee that the full `llvm.built` stage
can run its generated C++ tools.

The runtime stage builds shared `libc++.so.1`, `libc++abi.so.1`, and
`libunwind.so.1`. The final stage uses the staged libc++ headers and passes
`-stdlib=libc++` to C++ link commands through
`CMAKE_CXX_STANDARD_LIBRARIES`; it does not set `LLVM_ENABLE_LIBCXX=ON`
because that would also add the option to compile-only checks. LLVM tools
built during the stage therefore depend on the staged `libc++.so.1`. The
standalone C++ smoke test above confirms this: without
`LD_LIBRARY_PATH` the executable cannot load `libc++.so.1`; with the staged
library directory in `LD_LIBRARY_PATH`, it runs successfully.

`llvm_setup_rpath()` in LLVM's `AddLLVM.cmake` gives LLVM executables a
build-tree runpath such as `$ORIGIN/../lib`, which locates LLVM's own build
libraries. It does not include
`build/llvm-runtime-install/usr/lib`. The `-Wl,-rpath-link` option in this
project is only a link-time search path, not a substitute for that runtime
directory. Consequently, C++ tools executed by the build (for example,
TableGen tools) may fail to start unless the staged runtime directory is
available to the loader.

The `cmake --build $(LLVM_BUILD)` recipe now sets `LD_LIBRARY_PATH` to
`LLVM_RUNTIME_LIBDIR` (and preserves any existing value). This lets the build
run its generated C++ tools. Keep this setting scoped to the build stage; do
not add the absolute `build/llvm-runtime-install` path to the installed
toolchain's permanent RPATH. The installed toolchain copies runtime libraries
alongside its binaries under `/usr`, and LLVM's install runpath is relative.
The C/C++ smoke tests verify the compiler/linker and loader path separately;
they are not a substitute for completing the full LLVM build.

The Make implementation is:

```make
LLVM_RUNTIME_LD_LIBRARY_PATH := $(LLVM_RUNTIME_LIBDIR)$(if $(strip $(LD_LIBRARY_PATH)),:$(LD_LIBRARY_PATH))

$(LLVM_BUILD_ENV) env LD_LIBRARY_PATH='$(LLVM_RUNTIME_LD_LIBRARY_PATH)' \
  cmake --build $(LLVM_BUILD) --parallel $(JOBS)
```

The staged directory is first so the build uses the runtime it was configured
to link. The existing host `LD_LIBRARY_PATH`, if any, is appended rather than
discarded.

The `-stdlib=libc++` option is intentionally link-only in this configuration.
The C++ headers are selected separately by `-nostdinc++` and the staged
`-isystem` path; do not re-enable `LLVM_ENABLE_LIBCXX` without rechecking the
compiler's `-fPIC` feature test and generated compile flags.

## Make rebuilds, stamps, and protecting completed work

This is important before retrying a failed build:

* `build/stamps/llvm.runtime` depends on `mk/llvm-runtime.mk` and `config.mk`.
  Runtime-stage recipe/configuration changes belong in `mk/llvm-runtime.mk`.
  The final-stage flags and build environment are in `mk/toolchain.mk`, so
  changing only those no longer invalidates the completed runtime stage.
* `build/stamps/llvm.built` also depends on those files and on the runtime
  stamp. When Make runs its recipe, it starts with
  `rm -rf build/llvm-build build/llvm-install`. That intentionally discards
  those directories before reconfiguration.
* The stamp is touched at the end of a successful recipe. If a previous stamp
  exists and a later rebuild fails, the old stamp file can remain. A stamp's
  existence alone is not proof that the corresponding install tree is
  present or current. Check both the stamp's timestamp and the expected
  binaries/libraries.
* A failed CMake compiler check happens before LLVM source compilation in that
  attempt. But if Make has already removed the build/install directories, a
  previous successful compilation may still have been lost. Do not assume a
  retry is cheap just because the displayed error is from `TryCompile`.
* Do not delete build directories or mark a stage complete unless its
  corresponding outputs are present and verified. Before rerunning a
  high-level target, inspect the actual prerequisite state and confirm the
  runtime archive and install outputs exist.

After a successful `llvm.built`, verify the installed compiler before
building the rest of the system:

```sh
test -x build/llvm-install/usr/bin/clang
build/llvm-install/usr/bin/clang --version
build/llvm-install/usr/bin/clang -print-target-triple
```

Only then proceed to the broader image/profile target.

## References

* [Clang command-line reference](https://clang.llvm.org/docs/ClangCommandLineReference.html)
* [CMake `CMAKE_EXE_LINKER_FLAGS`](https://cmake.org/cmake/help/latest/variable/CMAKE_EXE_LINKER_FLAGS.html)
* [CMake `CMAKE_BUILD_RPATH`](https://cmake.org/cmake/help/latest/variable/CMAKE_BUILD_RPATH.html)
* [LLVM 21 `HandleLLVMStdlib.cmake`](https://github.com/llvm/llvm-project/blob/llvmorg-21.1.8/llvm/cmake/modules/HandleLLVMStdlib.cmake)
* [LLVM 21 `AddLLVM.cmake`](https://github.com/llvm/llvm-project/blob/llvmorg-21.1.8/llvm/cmake/modules/AddLLVM.cmake)
