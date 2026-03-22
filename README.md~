# SPARK-Verified Minimal Forth Interpreter

A minimal Forth interpreter written in Ada 2012 / SPARK 2014 with **zero unproved verification conditions**. Every line of core logic is formally verified by GNATprove — guaranteeing absence of runtime errors, buffer overflows, integer overflows, and index-out-of-range across all possible inputs.

## What It Does

An interactive Forth REPL that supports integer literals and 7 primitive words:

```
> 3 4 + .
 7  OK
> 5 DUP * .
 25  OK
> 1 2 SWAP - .
 1  OK
> 10 20 30 + + .
 60  OK
```

**Supported words:** `+` `-` `*` `DUP` `DROP` `SWAP` `.`

## Architecture

Three layers, each independently provable:

| Layer | Package | Lines | VCs Proved |
|-------|---------|-------|------------|
| Foundation | `Bounded_Stacks` (generic) | 78 | 28 |
| Virtual Machine | `Forth_VM` | 222 | 48 |
| Outer Interpreter | `Forth_Interpreter` | 320 | 62 |
| **Total** | | **831** (incl. main + tests) | **186** |

- Zero dynamic memory allocation — all data structures are stack-allocated with known compile-time sizes
- ~3.5 KB total static memory footprint (256-entry data stack + 64-entry dictionary + line buffer)
- Overflow-safe arithmetic via `Long_Long_Integer` intermediate computation
- Full functional correctness contracts: preconditions, postconditions, ghost functions, quantified frame conditions, and loop invariants

## Building

Requires GNAT and GNATprove (GNAT Community or GNAT Pro).

```bash
# Build
gprbuild -P forth_interpreter.gpr

# Run
./obj/main

# Formal verification (alt-ergo)
gnatprove -P forth_interpreter.gpr --level=2 --prover=alt-ergo

# Integration tests
gprbuild -P forth_interpreter.gpr test_integration.adb
./obj/test_integration
```

## Formal Verification Results

```
SPARK Analysis results        Total   Flow   Provers       Unproved
─────────────────────────────────────────────────────────────────────
Initialization                   34     34         .              .
Run-time Checks                  48      .   48 (alt-ergo)        .
Assertions                       27      .   27 (alt-ergo)        .
Functional Contracts             63      .   63 (alt-ergo)        .
Termination                      14     14         .              .
─────────────────────────────────────────────────────────────────────
Total                           186     48       138              0
```

Zero unproved. Every verification condition discharged.

## How This Was Made

This project was built in a single session on **2026-03-22** in roughly **90 minutes** (15:58 → 17:28 UTC) using [Kiro](https://kiro.dev) Pro+ with its spec-driven development workflow.

The process:
1. Started with a rough idea: "SPARK-verified Forth interpreter"
2. Kiro generated a requirements document, design document, and implementation plan
3. Kiro executed each task — writing Ada/SPARK code, running GNATprove, fixing proof failures, iterating until all VCs discharged
4. Human role: reviewing documents, approving direction, occasional guidance on proof strategy

**Cost:** 41 Kiro credits consumed (~453 → 494). At current pricing (2000 credits = $25 USD), that's roughly **$0.51** for a formally verified interpreter.

## Project Structure

```
├── forth_interpreter.gpr        # GNAT project file
├── src/
│   ├── bounded_stacks.ads/adb   # Generic bounded stack (SPARK)
│   ├── forth_vm.ads/adb         # VM state, dictionary, primitives (SPARK)
│   ├── forth_interpreter.ads/adb # Tokenizer + dispatch loop (SPARK)
│   ├── main.adb                 # Interactive REPL (non-SPARK)
│   └── test_integration.adb     # Integration test suite
└── .kiro/specs/                 # Kiro spec documents (requirements, design, tasks)
```

## License

Public domain. Do whatever you want with it.
