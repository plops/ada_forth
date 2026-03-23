[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/plops/ada_forth)

# SPARK-Verified Forth Interpreter

A Forth interpreter written in Ada 2012 / SPARK 2014 with **zero unproved verification conditions**. Every line of core logic is formally verified by GNATprove — guaranteeing absence of runtime errors, buffer overflows, integer overflows, and index-out-of-range across all possible inputs.

## What It Does

An interactive Forth REPL supporting integer literals, 12 built-in words, user-defined words, control flow, and variables:

```
> 3 4 + .
 7  OK
> 5 DUP * .
 25  OK
> : SQUARE DUP * ;
 OK
> 5 SQUARE .
 25  OK
> : ABS DUP 0 < IF -1 * THEN ;
 OK
> -5 ABS .
 5  OK
> VARIABLE X 42 X ! X @ .
 42  OK
```

### Built-in Words

| Category | Words |
|----------|-------|
| Arithmetic | `+` `-` `*` |
| Stack | `DUP` `DROP` `SWAP` |
| Comparison | `>` `<` `=` |
| Variables | `!` (store) `@` (fetch) |
| I/O | `.` (print) |

### Language Features

- **User-defined words** — `: NAME body ;` colon definitions compiled into a flat code space
- **Control flow** — `IF ... THEN` and `IF ... ELSE ... THEN` conditional branching inside definitions
- **Variables** — `VARIABLE name` declares a named memory cell; `!` stores, `@` fetches
- **Nested calls** — user-defined words can call other user-defined words (up to 32 levels deep)
- **Fuel-bounded execution** — 10,000 instruction step limit guarantees termination (catches infinite recursion)

## Architecture

Three layers, each independently provable:

| Layer | Package | Lines | VCs Proved |
|-------|---------|-------|------------|
| Foundation | `Bounded_Stacks` (generic) | 78 | 28 |
| Virtual Machine | `Forth_VM` | 876 | 196 |
| Outer Interpreter | `Forth_Interpreter` | 594 | 131 |
| **Total** | | **1,996** (incl. main + tests) | **424** |

- Zero dynamic memory allocation — all data structures are stack-allocated with known compile-time sizes
- ~7 KB total static memory footprint (256-entry data stack + 64-entry return stack + 1024-instruction code space + 64-cell variable memory + 64-entry dictionary)
- Overflow-safe arithmetic via `Long_Long_Integer` intermediate computation
- Full functional correctness contracts: preconditions, postconditions, loop invariants, and expression functions
- Iterative inner interpreter with explicit return stack (no Ada-level recursion)

## Building

Requires GNAT and GNATprove (GNAT Community or GNAT Pro).

```bash
# Build
gprbuild -P forth_interpreter.gpr

# Run
./obj/main

# Formal verification (alt-ergo only, all VCs)
gnatprove -P forth_interpreter.gpr --level=2 --prover=alt-ergo -j0

# Integration tests
gprbuild -P test_integration.gpr
./obj/test_integration
```

## Formal Verification Results

```
SPARK Analysis results        Total   Flow   Provers              Unproved
───────────────────────────────────────────────────────────────────────────
Initialization                   71     71         .                    .
Run-time Checks                 148      .   148 (alt-ergo)             .
Assertions                       39      .    39 (alt-ergo)             .
Functional Contracts            149      .   149 (alt-ergo)             .
Termination                      17     17         .                    .
───────────────────────────────────────────────────────────────────────────
Total                           424     88       336                    0
```

Zero unproved. Every verification condition discharged by alt-ergo alone.

## How This Was Made

This project was built using [Kiro](https://kiro.dev) Pro+ with its spec-driven development workflow.

| Phase | Time | Credits | VCs |
|-------|------|---------|-----|
| Initial interpreter (7 primitives) | ~90 min (15:58–17:28 UTC) | ~41 (453 → 494) | 186 |
| Extended ops (user-defined words, control flow, variables) | ~4.5 hrs (19:05–23:25 UTC) | ~266 (494 → 760) | 424 |
| **Total** | **~6 hours** | **~307** | **424** |

All on **2026-03-22**. At current Kiro Pro+ pricing (2000 credits = $25 USD), the entire project cost roughly **$3.84** in credits.

The process for each phase: Kiro generated a requirements document, design document, and implementation plan. Then it executed each task — writing Ada/SPARK code, running GNATprove, fixing proof failures, iterating until all VCs discharged. Human role was reviewing documents, approving direction, and occasional guidance on proof strategy. The extended ops took longer because GNATprove proof obligations for the inner interpreter, compilation mode, and control flow patching required more iteration to get alt-ergo to discharge everything.

## Project Structure

```
├── forth_interpreter.gpr        # GNAT project file (main)
├── test_integration.gpr         # GNAT project file (tests)
├── src/
│   ├── bounded_stacks.ads/adb   # Generic bounded stack (SPARK)
│   ├── forth_vm.ads/adb         # VM state, types, primitives, inner interpreter (SPARK)
│   ├── forth_interpreter.ads/adb # Tokenizer, compiler, outer interpreter (SPARK)
│   ├── main.adb                 # Interactive REPL (non-SPARK)
│   └── test_integration.adb     # Integration test suite (55 tests)
└── .kiro/specs/                 # Kiro spec documents (requirements, design, tasks)
```

## License

Public domain. Do whatever you want with it.
