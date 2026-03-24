# Minimal build vs standard build (comparison)

This project supports two build “flavors” that share the same VM/interpreter logic but differ in runtime dependencies and I/O:

## Standard build (default)

**Goal:** developer-friendly REPL and easy portability within GNAT’s normal runtime model.

- **Entrypoint:** `src/main.adb`
- **I/O:** `Ada.Text_IO` (line prompting, `Get_Line`, formatted output)
- **Runtime model:** normal GNAT runtime (exceptions enabled in the host program; standard startup code)
- **Build tool:** `gprbuild -P forth_interpreter.gpr`
- **Output binary:** `ada-forth` (configured in `forth_interpreter.gpr`)
- **Tradeoffs:**
  - Larger binary due to full Ada runtime + Text_IO.
  - More convenient during development (robust console I/O, better diagnostics).

## Minimal build

**Goal:** produce a very small Linux binary (target **< 30KB**) by bypassing most of the Ada runtime and using direct syscalls.

- **Entrypoint:** `src/mini_main.adb`
- **I/O:** `src/mini_io.*` using Linux `read(2)`/`write(2)` via C imports
- **Runtime model:** configured to minimize/avoid runtime features:
  - `pragma No_Run_Time`
  - restrictions such as no exception propagation / secondary stack (see `gnat.adc` and `src/mini_main.adb`)
- **Build tool:** `./build_minimal.sh` (scripted build, not a plain `.gpr` build)
- **Implementation detail:** the script patches `forth_vm.adb` usage of `Ada.Text_IO` so the VM’s `.` word output uses `Mini_IO` instead.
- **Output binary:** `forth-mini` (as described in this doc)
- **Tradeoffs:**
  - Significantly smaller binary; fewer dependencies.
  - Less ergonomic I/O (no full Text_IO facilities).
  - More platform-specific (Linux syscalls / C ABI expectations).

## What stays the same between builds

- The **Forth language behavior** (word set, dictionary, compilation/execution model) is intended to remain identical.
- The **VM + interpreter architecture** is shared; only the outermost I/O and startup/runtime wiring differ.

## Quick “which should I use?”
- Use the **standard build** for day-to-day development, debugging, and CI verification.
- Use the **minimal build** when you care about **binary size** and are targeting **Linux** with minimal runtime features.

## Usage

Minimal build:

```bash
./build_minimal.sh
```

Standard build:

```bash
gprbuild -P forth_interpreter.gpr -j0
./obj/ada-forth
```
