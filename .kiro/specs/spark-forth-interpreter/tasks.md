# Implementation Plan: SPARK-Verified Minimal Forth Interpreter

## Overview

Implement a minimal Forth interpreter in Ada 2012 / SPARK 2014 across three phases: a formally verified bounded stack, a Forth VM with primitive word executors, and an outer interpreter with tokenizer and dispatch loop. All SPARK packages use `SPARK_Mode => On`, zero dynamic memory allocation, and formal contracts provable by GNATprove. A GNAT project file and Main procedure tie everything together.

## Tasks

- [x] 1. Project setup and GNAT project file
  - [x] 1.1 Create the GNAT project file (`forth_interpreter.gpr`)
    - Define source directories, object directory, main procedure, and Ada 2012 compiler switches
    - Include `-gnata` for assertion checking and SPARK-related switches
    - _Requirements: 13.1, 14.4_

- [x] 2. Phase 1 — Bounded Stack (generic SPARK package)
  - [x] 2.1 Create `bounded_stacks.ads` — Bounded_Stacks generic package specification
    - Declare the generic package with `Max_Depth : Positive` parameter and `SPARK_Mode => On`
    - Define the `Stack` private type with `Data_Array` and `Top : Depth_Range`
    - Declare `Is_Empty`, `Is_Full`, `Size`, `Peek` query functions
    - Declare `Element_At` ghost function with `Ghost` aspect and precondition `I in 1 .. Size(S)`
    - Declare `Push` with precondition `not Is_Full` and postconditions for size increment, `Peek = Value`, and frame preservation via `Element_At` quantification
    - Declare `Pop` with precondition `not Is_Empty` and postconditions for size decrement, `Value = Peek(S'Old)`, and frame preservation
    - Declare `Empty_Stack` constant
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3, 3.4, 4.1, 4.2, 4.3_

  - [x] 2.2 Create `bounded_stacks.adb` — Bounded_Stacks generic package body
    - Implement `Is_Empty`, `Is_Full`, `Size`, `Peek` as expression functions over `S.Top` and `S.Data`
    - Implement `Element_At` as `S.Data(I)` (ghost, erased at runtime)
    - Implement `Push`: increment `Top`, assign `S.Data(S.Top) := Value`
    - Implement `Pop`: read `S.Data(S.Top)` into `Value`, decrement `Top`
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 3.1, 3.2, 3.3_

  - [ ]* 2.3 Write property test for Push-Pop round trip
    - **Property 1: Push-Pop Round Trip**
    - **Validates: Requirements 2.1, 2.2, 3.1, 3.2**

  - [ ]* 2.4 Write property test for Push frame preservation
    - **Property 2: Push Frame Preservation**
    - **Validates: Requirements 2.3**

  - [ ]* 2.5 Write property test for Pop frame preservation
    - **Property 3: Pop Frame Preservation**
    - **Validates: Requirements 3.3**

  - [ ]* 2.6 Write property test for stack query consistency
    - **Property 4: Stack Query Consistency**
    - **Validates: Requirements 1.3, 1.4, 1.5**

- [x] 3. Checkpoint — Verify Phase 1
  - Ensure `bounded_stacks.ads` and `bounded_stacks.adb` compile cleanly and all GNATprove VCs for Phase 1 are discharged. Ask the user if questions arise.

- [x] 4. Phase 2 — Forth VM (state record, dictionary, primitive executors)
  - [x] 4.1 Create `forth_vm.ads` — Forth_VM package specification
    - Declare constants `Stack_Capacity`, `Max_Dict_Entries`, `Max_Word_Length`
    - Instantiate `Data_Stacks` from `Bounded_Stacks` with `Max_Depth => Stack_Capacity`
    - Define `Word_Name` subtype, `Primitive_Op` enumeration, `Dict_Entry` record, `Dict_Array` type
    - Define `VM_State` record with `Data_Stack`, `Dictionary`, `Dict_Size`, `Halted` fields
    - Declare `Dict_Entries_Valid` helper expression function that unrolls the first 7 entries explicitly and falls back to quantification for entries 8+, to aid alt-ergo proof discharge
    - Declare `VM_Is_Valid` expression function delegating to `Dict_Entries_Valid`
    - Declare `Initialize` with postcondition `VM_Is_Valid(VM) and Data_Stacks.Is_Empty(VM.Data_Stack)`
    - Declare arithmetic executors (`Execute_Add`, `Execute_Sub`, `Execute_Mul`) with `Success : out Boolean` parameter for overflow-safe operation, preconditions (VM validity + minimum stack depth 2), and postcondition `VM_Is_Valid(VM)`
    - Declare stack manipulation executors (`Execute_Dup`, `Execute_Drop`, `Execute_Swap`, `Execute_Dot`) with appropriate preconditions and postcondition `VM_Is_Valid(VM)`
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.2, 6.3, 7.1, 7.2, 7.3, 7.4, 7.5, 8.1, 8.2, 8.3, 8.4, 9.1, 9.2, 9.3_

  - [x] 4.2 Create `forth_vm.adb` — Forth_VM package body
    - Define `Default_Dict` constant aggregate with all 7 built-in primitives for prover-friendly initialization
    - Implement `Initialize`: set `Data_Stack` to `Empty_Stack`, assign `Default_Dict` to `Dictionary`, set `Dict_Size := 7`, `Halted := False`
    - Implement `Execute_Add`, `Execute_Sub`, `Execute_Mul` with overflow-safe `Long_Long_Integer` intermediate arithmetic: pop two values, compute in wide type, check `Integer` range, push result and set `Success := True` on success, or restore operands and set `Success := False` on overflow
    - Implement `Execute_Dup`: peek top, push copy
    - Implement `Execute_Drop`: pop and discard
    - Implement `Execute_Swap`: pop two, push in reversed order
    - Implement `Execute_Dot`: pop top value for output (use a SPARK_Mode => Off body for Ada.Text_IO)
    - _Requirements: 6.2, 7.1, 7.2, 7.3, 7.5, 8.1, 8.2, 8.3, 8.4, 9.1_

  - [ ]* 4.3 Write property test for VM validity preservation under primitives
    - **Property 5: VM Validity Preservation Under Primitives**
    - **Validates: Requirements 7.1, 7.2, 7.3, 8.1, 8.2, 8.3, 8.4**

  - [ ]* 4.4 Write property test for arithmetic primitive correctness
    - **Property 6: Arithmetic Primitive Correctness**
    - **Validates: Requirements 7.1, 7.2, 7.3**

  - [ ]* 4.5 Write property test for Swap involution
    - **Property 7: Swap Involution**
    - **Validates: Requirement 8.3**

  - [ ]* 4.6 Write property test for Dup duplicates top
    - **Property 8: Dup Duplicates Top**
    - **Validates: Requirement 8.1**

- [-] 5. Checkpoint — Verify Phase 2
  - Ensure `forth_vm.ads` and `forth_vm.adb` compile cleanly and all GNATprove VCs for Phase 2 are discharged. Ask the user if questions arise.

- [ ] 6. Phase 3 — Outer Interpreter (token reader, dispatch loop)
  - [ ] 6.1 Create `forth_interpreter.ads` — Forth_Interpreter package specification
    - Declare constants `Max_Line_Length`, `Max_Token_Length`
    - Define `Line_Buffer` subtype, `Token` record, `Interpret_Result` enumeration
    - Declare `Interpret_Line` with precondition `VM_Is_Valid(VM) and Len <= Max_Line_Length` and postcondition `VM_Is_Valid(VM)`
    - _Requirements: 10.1, 10.2, 11.1, 11.4, 11.5, 12.4_

  - [ ] 6.2 Create `forth_interpreter.adb` — Forth_Interpreter package body
    - Implement internal helpers: `Skip_Spaces`, `Read_Token`, `Lookup`, `Has_Enough_Operands`, `Try_Parse_Integer`, `Dispatch`
    - Implement `Interpret_Line` main loop with `pragma Loop_Invariant (Forth_VM.VM_Is_Valid (VM))` and `pragma Loop_Invariant (Pos in 1 .. Len + 1)`
    - Handle dictionary lookup → dispatch, integer literal → push, and unknown word → return `Unknown_Word`
    - Return `Stack_Error` when operand depth is insufficient or stack is full on push
    - _Requirements: 10.1, 10.3, 11.1, 11.2, 11.3, 11.4, 11.5, 12.1, 12.2, 12.3, 12.4_

  - [ ]* 6.3 Write property test for tokenizer whitespace normalization
    - **Property 9: Tokenizer Whitespace Normalization**
    - **Validates: Requirements 10.1, 10.3**

  - [ ]* 6.4 Write property test for interpreter end-to-end correctness
    - **Property 10: Interpreter End-to-End Correctness**
    - **Validates: Requirements 11.1, 11.3, 12.4**

  - [ ]* 6.5 Write property test for error preservation of VM state
    - **Property 11: Error Preservation of VM State**
    - **Validates: Requirements 12.1, 12.3**

  - [ ]* 6.6 Write property test for VM_Is_Valid characterization
    - **Property 12: VM_Is_Valid Characterization**
    - **Validates: Requirements 6.1, 9.3**

- [ ] 7. Checkpoint — Verify Phase 3
  - Ensure `forth_interpreter.ads` and `forth_interpreter.adb` compile cleanly and all GNATprove VCs for Phase 3 are discharged. Ask the user if questions arise.

- [ ] 8. Main procedure and integration
  - [ ] 8.1 Create `main.adb` — Main procedure
    - Declare `Main` with `SPARK_Mode => Off` (uses Ada.Text_IO)
    - Initialize VM via `Forth_VM.Initialize`
    - Read a line of input into a `Line_Buffer`, call `Forth_Interpreter.Interpret_Line`, and print the result
    - Optionally loop for interactive REPL until EOF or halt
    - _Requirements: 5.1, 6.2, 11.1, 14.1, 14.2, 14.3, 14.4_

  - [ ]* 8.2 Write integration tests for end-to-end Forth expressions
    - Test known expressions like `"3 4 + ."`, `"5 DUP * ."`, `"1 2 SWAP - ."`
    - Verify correct output and `OK` result
    - Test error cases: unknown word, stack underflow, stack overflow
    - _Requirements: 11.1, 12.1, 12.2, 12.3, 12.4_

- [ ] 9. Final checkpoint — Full build and verification
  - Ensure the entire project builds with `gprbuild -P forth_interpreter.gpr`, all GNATprove VCs are discharged at level 2, and the interpreter correctly executes sample Forth programs. Ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- The primary verification strategy is GNATprove formal proof — property tests serve as supplementary runtime checks
- Each phase is independently compilable and provable before moving to the next
- All SPARK packages use `SPARK_Mode => On`; only `Main` and I/O wrappers use `SPARK_Mode => Off`
- Checkpoints ensure incremental verification at each phase boundary
