---
inclusion: auto
---

# SPARK / GNATprove Toolchain Context

## Available Provers

This environment only has **alt-ergo** installed. The z3 and cvc5 solvers are **not** available.

When running GNATprove, always use:

```
gnatprove -P <project>.gpr --level=2 --prover=alt-ergo
```

Never pass `--prover=z3`, `--prover=cvc5`, or `--prover=z3,cvc5` — they will fail with an error.

Ues flag -j0 to use all threads.

## Project File

The GNAT project file is `forth_interpreter.gpr` at the workspace root. It references `main.adb` as the main unit, which may not exist yet during early phases. If compilation fails because `main.adb` is missing, temporarily comment out the `for Main use` line, run the build/prove, then restore it.
