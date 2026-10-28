# SimpleLinux

> **WORK IN PROGRESS**

A minimal Linux distribution built from source using the **Linux kernel, musl libc, LLVM/Clang, and BusyBox**.

to build kernel, musl and busybox
```
make
```
to rebuild rootfs (after changing in Makefile inittab etc.)
```
make rootfs
```
clean
```
make clean
```
boot iso with qemu 
```
./run_qemu.sh
```

