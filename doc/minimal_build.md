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

### What prevents the standard build from being “poisoned” by minimal-build artifacts?

1. **Different build pipelines**
   - Standard build uses GNAT project files and compiles into the configured object directory (`obj/`).
   - Minimal build is script-driven and typically compiles in an isolated temporary directory (as described earlier in this document), producing its own binary.

2. **Different mains mean unused units are not linked**
   - `forth_interpreter.gpr` only lists `main.adb` as its `Main`.
   - Even though `mini_main.adb` / `mini_io.*` live in `src/`, they are not pulled into the standard executable unless something `with`s them from the `main` dependency tree.

3. **The only real “poisoning” risk is source patching**
   - If `build_minimal.sh` patches a *tracked* source file in-place (e.g., editing `src/forth_vm.adb` to swap `Ada.Text_IO` for `Mini_IO`) and does not restore it, that *would* affect subsequent standard builds.
   - The minimal build should therefore patch **only copies** of sources in a temporary build directory (or the patch must be reverted afterwards). This is the primary guardrail to verify in the script.

4. **Object file leftovers are normally harmless (but can confuse incremental builds)**
   - Old `.o`/`.ali` in `obj/` generally won’t affect correctness if the project file and dependencies are consistent, but they can lead to surprising incremental behavior if build flags change.
   - A clean rebuild (`rm -rf obj`) is the simplest “reset” if you suspect mixed artifacts.

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
