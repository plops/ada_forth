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

## Separation between standard build and minimal build

The two build flavors are separated by **build tooling and entrypoints**, not by two different source trees:

- The **standard build** is built via `gprbuild -P forth_interpreter.gpr` and uses **`src/main.adb`** as the main unit.
- The **minimal build** is built via `./build_minimal.sh` and uses **`src/mini_main.adb`** plus **`src/mini_io.*`**, and (per the script) may patch I/O usage inside the VM.

### Did the minimal build patch (and therefore poison) repo files?

From the files currently in the repo snapshot you shared **there is no evidence that anything was permanently patched**:

- `src/forth_vm.adb` still `with Ada.Text_IO;` and `Execute_Dot` still calls `Ada.Text_IO.Put`, which indicates the VM source in `src/` was **not** rewritten to use `Mini_IO`.
- The standard build (`gprbuild -P forth_interpreter.gpr -j0`) reports **“up to date”**, which is consistent with `src/` not being modified by the minimal build.

However, based on the minimal build output alone, we **cannot prove** what `build_minimal.sh` did, because:
- it could patch **copies** of files in a temp directory (safe), or
- it could patch tracked files and then revert them (also safe), or
- it could patch tracked files and leave them modified (poisoning risk).

The warning spam (`pragma No_Run_Time is ignored`) is coming from compilation configuration (`gnat.adc` / `mini_main.adb`), not from patching.

#### How to verify locally (recommended)
After running `./build_minimal.sh`, check for a dirty working tree:

```bash
git status --porcelain
```

If that prints nothing, the minimal build did **not** leave tracked files modified.

If you want, add `build_minimal.sh` to the chat and I can review it to confirm it only patches temporary copies (and if it doesn’t, I can refactor it so it cannot poison `src/`).

### Recommended practice

- Ensure `build_minimal.sh`:
  - uses an isolated build directory (e.g., under `/tmp` or a local temp directory),
  - never edits tracked files under `src/`,
  - and emits its binary outside `obj/` (or into its own dedicated object dir).

If you add `build_minimal.sh` to the chat, I can verify whether it patches files safely (copy-only) and, if needed, refactor it so the standard build is provably insulated.

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
