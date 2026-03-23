# Minimal Build of Ada-Forth

This document describes how to create a minimal Linux binary of the Forth interpreter, optimized for size with a target of < 30KB.

## Principles of the Minimal Build

1. **Bypass the Ada Runtime (GNAT Runtime)**: By default, Ada programs link with a significantly large runtime (GNAT) which handles multitasking, exception handling, and standard I/O. For a minimal binary, we bypass this by providing a direct C-style entry point and using low-level syscalls.
2. **Minimal I/O Layer**: The `Mini_IO` package in `src/` implements basic `Put`, `Get_Line`, and `Put_Int` operations using only the Linux `write` and `read` system calls.
3. **Aggressive Section Garbage Collection**: Compiling with `-ffunction-sections` and `-fdata-sections` allows the linker to perform "garbage collection" on unused code sections via the `--gc-sections` flag.
4. **Symbol Stripping**: All symbol tables and debugging metadata are removed in the final build step.

## Build Process

The `build_minimal.sh` script automates the following steps:

1. **Sources Preparation**: Core files from `src/` are copied to a temporary build directory.
2. **Source Patching**: `forth_vm.adb` is patched on the fly to use `Mini_IO` instead of the standard `Ada.Text_IO`.
3. **C Entry Point**: A small `entry.c` file is created to initialize the system and call the Ada logic (`_ada_mini_main`).
4. **Direct Object Compilation**: All Ada units are compiled directly to object files (`.o`) with aggressive size optimizations (`-Os`).
5. **Direct Binary Linking**: `gcc` is used as the linker instead of `gnatlink` to avoid pulling in the standard GNAT startup code.

## Prerequisites

- GNAT (GCC) toolchain.
- Standard C library (libc.a/libc.so) for syscall stubs.

## Usage

Run the build script from the root directory:

```bash
./build_minimal.sh
```

The resulting `forth-mini` binary will be approximately **19-25KB** in size.
