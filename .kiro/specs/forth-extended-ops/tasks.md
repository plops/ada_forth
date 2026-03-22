# Implementation Plan: Extended Forth Operations (User-Defined Words, Control Flow, Variables)

## Overview

Extend the existing SPARK-verified Forth interpreter in three incremental phases: (1) user-defined words with colon definitions and an iterative inner interpreter, (2) comparison operators and IF/ELSE/THEN control flow compilation, (3) variables with VARIABLE/!/@ operations. Each phase is independently verifiable by GNATprove using only alt-ergo. All code is Ada/SPARK with zero dynamic allocation.

## Tasks

- [x] 1. Phase 1 — Extended VM Types and State
  - [x] 1.1 Extend Forth_VM package specification with new types and VM_State fields
    - Add constants: Return_Capacity (64), Max_Code_Size (1024), Max_Variables (64), Max_Exec_Steps (10_000)
    - Instantiate Return_Stacks from Bounded_Stacks with Max_Depth => Return_Capacity
    - Define Instruction_Kind enumeration (Inst_Primitive, Inst_Call, Inst_Literal, Inst_Branch_If_Zero, Inst_Jump, Inst_Var_Addr, Inst_Noop)
    - Define Code_Index, Var_Index subtypes, Instruction record, Code_Array, Var_Array types
    - Extend Primitive_Op with Op_Greater, Op_Less, Op_Equal, Op_Store, Op_Fetch
    - Define Entry_Kind enumeration (Primitive_Entry, User_Defined_Entry, Variable_Entry)
    - Extend Dict_Entry record with Kind, Body_Start, Body_Len, Var_Addr fields
    - Extend VM_State record with Return_Stack, Code, Code_Size, Memory, Var_Count, Compiling, Comp_Start, Comp_Name, Comp_Name_Len fields
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

  - [x] 1.2 Extend VM_Is_Valid and Dict_Entries_Valid
    - Extend Dict_Entries_Valid unrolled pattern to cover new built-in entries (entries 8–12 for >, <, =, !, @)
    - Keep VM_Is_Valid as simple delegation to Dict_Entries_Valid plus Code_Size and Var_Count range checks
    - Add Comp_Name_Len > 0 check when Compiling = True
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x] 1.3 Update Initialize procedure to register new built-in primitives
    - Register Op_Greater (">"), Op_Less ("<"), Op_Equal ("="), Op_Store ("!"), Op_Fetch ("@") in the dictionary
    - Ensure Return_Stack is empty, Code_Size = 0, Var_Count = 0, Compiling = False after initialization
    - Ensure VM_Is_Valid holds and all original 7 primitives are still registered identically
    - _Requirements: 19.3, 3.5_

  - [x] 1.4 Add procedure declarations for new operations in forth_vm.ads
    - Declare Emit_Instruction with Pre => VM_Is_Valid and Compiling, Post => VM_Is_Valid
    - Declare Finalize_Definition with Pre => VM_Is_Valid and Compiling and Comp_Name_Len > 0, Post => VM_Is_Valid and not Compiling
    - Declare Execute_Word with Pre/Post contracts per design (Body_Start/Body_Len validity, Return_Stack empty on entry and exit)
    - Declare Execute_Greater, Execute_Less, Execute_Equal with Pre => Size >= 2, Post => VM_Is_Valid
    - Declare Execute_Store with Pre => Size >= 2, Execute_Fetch with Pre => not Is_Empty
    - _Requirements: 6.1, 6.2, 6.3, 7.1, 7.2, 7.3, 8.1, 8.5, 8.6, 12.1, 12.2, 12.3, 15.1, 15.3_

- [x] 2. Phase 1 — Core Implementation (Emit, Finalize, Execute_Word)
  - [x] 2.1 Implement Emit_Instruction in forth_vm.adb
    - If Code_Size < Max_Code_Size: increment Code_Size, store instruction, OK := True
    - If Code_Size = Max_Code_Size: OK := False, no modification
    - Add pragma Assert breadcrumbs to guide alt-ergo through VM_Is_Valid preservation
    - _Requirements: 6.1, 6.2, 6.3_

  - [x] 2.2 Implement Finalize_Definition in forth_vm.adb
    - If Dict_Size < Max_Dict_Entries: create User_Defined_Entry with Body_Start = Comp_Start + 1 and Body_Len = Code_Size - Comp_Start, increment Dict_Size, set Compiling := False, OK := True
    - If Dict_Size = Max_Dict_Entries: roll back Code_Size to Comp_Start, set Compiling := False, OK := False
    - Ensure Body_Len >= 1 check (empty body should fail)
    - _Requirements: 7.1, 7.2, 7.3_

  - [x] 2.3 Implement Execute_Word (iterative inner interpreter) in forth_vm.adb
    - Implement the main execution loop with PC, End_Addr, Steps local variables
    - Add loop invariants: VM_Is_Valid, PC bounds (1 .. Max_Code_Size + 1), End_Addr bounds, Steps <= Max_Exec_Steps
    - Implement inner return-from-word loop: pop 2 entries (Saved_End, Saved_PC), validate, restore PC/End_Addr
    - Implement fuel check: if Steps >= Max_Exec_Steps then Success := False and exit
    - Implement instruction dispatch for Inst_Primitive (call Dispatch_Primitive, PC + 1), Inst_Literal (push Operand, PC + 1), Inst_Noop (PC + 1)
    - Implement Inst_Call: validate dictionary index and entry kind, check Return_Stack has room for 2 entries, push return context (PC + 1, End_Addr), jump to callee body
    - Implement Inst_Branch_If_Zero: pop TOS, if zero jump to Operand (validate in body range), else PC + 1
    - Implement Inst_Jump: validate Operand in body range, jump unconditionally
    - Implement Inst_Var_Addr: push Operand onto Data_Stack, PC + 1
    - Implement error-path drain loop: if not Success, pop all Return_Stack entries with loop invariant VM_Is_Valid
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 9.1, 9.2, 9.3, 10.1, 10.2, 10.3, 10.4, 11.1, 11.2, 11.3, 18.1, 18.2, 18.3, 18.4, 18.5_

  - [x] 2.4 Implement or extend Dispatch_Primitive helper in forth_vm.adb
    - Add cases for Op_Greater, Op_Less, Op_Equal, Op_Store, Op_Fetch to the existing dispatch
    - Ensure all new cases preserve VM_Is_Valid
    - _Requirements: 12.1, 12.2, 12.3, 15.1, 15.3_

  - [ ]* 2.5 Write property test for VM_Is_Valid preservation (Property 1)
    - **Property 1: VM_Is_Valid Preservation Under All New Operations**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 6.3, 7.3, 8.5, 12.4, 15.5**

  - [ ]* 2.6 Write property test for Execute_Word termination and postconditions (Property 3)
    - **Property 3: Execute_Word Terminates and Preserves Postconditions**
    - **Validates: Requirements 8.1, 8.5, 9.1, 9.2, 9.3, 11.1, 11.2**

  - [ ]* 2.7 Write property test for return stack balance (Property 9)
    - **Property 9: Return Stack Balance Across Word Calls**
    - **Validates: Requirements 8.5, 10.1, 10.2, 11.1, 11.2**

- [x] 3. Phase 1 — Extended Outer Interpreter (Compilation Mode)
  - [x] 3.1 Extend Interpret_Result with Compile_Error value in forth_interpreter.ads
    - Add Compile_Error to the Interpret_Result enumeration
    - _Requirements: 16.5_

  - [x] 3.2 Extend Lookup to return entry index instead of just Op
    - Modify Lookup to output Found (Boolean), Entry_Idx (Natural) instead of just the Op
    - Update all existing callers of Lookup
    - _Requirements: 16.1, 16.2_

  - [x] 3.3 Implement compilation mode in Interpret_Line
    - When ":" is encountered in interpretation mode: read next token as word name, enter compilation mode (set Compiling, Comp_Start, Comp_Name, Comp_Name_Len)
    - If ":" is last token with no name following: return Compile_Error without entering compilation mode
    - When ";" is encountered in compilation mode: call Finalize_Definition, return Compile_Error if it fails
    - For other tokens in compilation mode: call Compile_Token helper
    - Maintain VM_Is_Valid loop invariant throughout
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 17.1, 17.2, 17.3, 17.4_

  - [x] 3.4 Implement Compile_Token helper procedure
    - Lookup token in dictionary: Primitive_Entry → emit Inst_Primitive, User_Defined_Entry → emit Inst_Call, Variable_Entry → emit Inst_Var_Addr
    - If not found: try parsing as integer literal → emit Inst_Literal
    - If neither: return OK := False (unknown word during compilation)
    - On emit failure (code space full): roll back Code_Size to Comp_Start, set Compiling := False, return failure
    - _Requirements: 5.5, 5.6, 5.7, 17.1, 17.3_

  - [x] 3.5 Extend interpretation mode dispatch for User_Defined_Entry and Variable_Entry
    - When a User_Defined_Entry is found: call Execute_Word with Body_Start and Body_Len
    - When a Variable_Entry is found: push Var_Addr onto Data_Stack
    - Preserve existing Primitive_Entry dispatch unchanged
    - _Requirements: 16.1, 16.2, 19.1, 19.2_

  - [ ]* 3.6 Write property test for colon definition round trip (Property 2)
    - **Property 2: Colon Definition Round Trip**
    - **Validates: Requirements 2.2, 5.1, 5.3, 5.4, 7.1**

  - [ ]* 3.7 Write property test for token compilation correctness (Property 10)
    - **Property 10: Token Compilation Correctness**
    - **Validates: Requirements 5.5, 5.6, 5.7**

  - [ ]* 3.8 Write property test for compilation mode isolation (Property 8)
    - **Property 8: Compilation Mode Isolation**
    - **Validates: Requirements 5.2, 16.3**

- [ ] 4. Phase 1 — GNATprove Verification and Integration Tests
  - [x] 4.1 Run GNATprove and resolve all verification conditions for Phase 1
    - Run: `gnatprove -P forth_interpreter.gpr --level=2 --prover=alt-ergo`
    - All VCs must be discharged (zero unproved) including all new code
    - Add pragma Assert breadcrumbs as needed to guide alt-ergo
    - Fix any loop invariant or contract issues until fully proved
    - _Requirements: 20.1, 20.2, 20.3, 20.4, 20.5_

  - [x] 4.2 Add integration tests for user-defined words in test_integration.adb
    - Test `: SQUARE DUP * ; 5 SQUARE .` → prints 25
    - Test nested calls: `: SQUARE DUP * ; : CUBE DUP SQUARE * ; 3 CUBE .` → prints 27
    - Test error: undefined word in colon definition returns Compile_Error
    - Test backward compatibility: all existing test cases still pass
    - _Requirements: 5.1, 5.3, 8.1, 19.1, 19.2_

- [x] 5. Checkpoint — Phase 1 Complete
  - Ensure all GNATprove VCs pass with zero unproved, all integration tests pass. Ask the user if questions arise.

- [x] 6. Phase 2 — Comparison Operators
  - [x] 6.1 Implement Execute_Greater, Execute_Less, Execute_Equal in forth_vm.adb
    - Pop two values (A then B), push -1 if condition holds, 0 otherwise
    - Execute_Greater: push -1 if B > A, else 0
    - Execute_Less: push -1 if B < A, else 0
    - Execute_Equal: push -1 if A = B, else 0
    - Net stack effect: -1 (two popped, one pushed)
    - _Requirements: 12.1, 12.2, 12.3, 12.4_

  - [ ]* 6.2 Write property test for comparison operators (Property 7)
    - **Property 7: Comparison Operators Produce Forth Boolean**
    - **Validates: Requirements 12.1, 12.2, 12.3, 12.4**

- [x] 7. Phase 2 — IF/ELSE/THEN Compilation
  - [x] 7.1 Implement IF/ELSE/THEN compilation in Interpret_Line
    - Add a local compile-time control flow stack (array + top index, not the VM return stack)
    - IF: emit Inst_Branch_If_Zero with placeholder (Operand = 0), push Code_Size onto CF stack
    - ELSE: emit Inst_Jump with placeholder, patch IF's branch target to Code_Size + 1, push Code_Size onto CF stack
    - THEN: pop CF stack, patch the branch target to Code_Size + 1
    - IF/THEN without ELSE: only Inst_Branch_If_Zero emitted, target points past THEN
    - At ";": check CF stack is empty, if not return Compile_Error and roll back
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 17.5_

  - [x] 7.2 Ensure Inst_Branch_If_Zero and Inst_Jump are handled in Execute_Word
    - Verify the Inst_Branch_If_Zero and Inst_Jump cases implemented in task 2.3 work correctly with the compiled branch targets
    - Inst_Branch_If_Zero: pop TOS, if zero jump to Operand, else fall through (PC + 1)
    - Inst_Jump: unconditionally jump to Operand
    - Both validate target is within body range (Body_Start .. End_Addr)
    - _Requirements: 13.5, 13.6, 13.7, 18.2_

  - [ ]* 7.3 Write property test for branch target validity (Property 4)
    - **Property 4: Branch Target Validity**
    - **Validates: Requirements 13.1, 13.2, 13.3, 13.4**

- [x] 8. Phase 2 — GNATprove Verification and Integration Tests
  - [x] 8.1 Run GNATprove and resolve all verification conditions for Phase 2
    - Run: `gnatprove -P forth_interpreter.gpr --level=2 --prover=alt-ergo`
    - All VCs must be discharged including comparison operators and control flow compilation
    - _Requirements: 20.1, 20.2, 20.3_

  - [x] 8.2 Add integration tests for control flow in test_integration.adb
    - Test `: ABS DUP 0 < IF -1 * THEN ; -5 ABS .` → prints 5
    - Test IF/ELSE/THEN: `: SIGN DUP 0 > IF DROP 1 ELSE DUP 0 < IF DROP -1 ELSE DROP 0 THEN THEN ;`
    - Test comparison operators: `5 3 > .` → prints -1, `3 5 > .` → prints 0
    - Test fuel exhaustion with self-recursive word: `: LOOP LOOP ; LOOP` → Stack_Error
    - _Requirements: 12.1, 12.2, 12.3, 13.1, 13.4, 13.5, 13.6, 13.7, 9.2_

- [x] 9. Checkpoint — Phase 2 Complete
  - Ensure all GNATprove VCs pass with zero unproved, all integration tests pass. Ask the user if questions arise.

- [ ] 10. Phase 3 — Variables
  - [~] 10.1 Implement Execute_Store and Execute_Fetch in forth_vm.adb
    - Execute_Store: pop address (TOS) and value (NOS), if address in 0 .. Var_Count - 1 store value in Memory, else restore stack and Success := False
    - Execute_Fetch: pop address (TOS), if address in 0 .. Var_Count - 1 push Memory(address), else restore stack and Success := False
    - Both preserve VM_Is_Valid regardless of Success
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5_

  - [~] 10.2 Implement Create_Variable in forth_vm.adb or forth_interpreter.adb
    - Check Dict_Size < Max_Dict_Entries and Var_Count < Max_Variables
    - Create Variable_Entry with Var_Addr = Var_Count, initialize Memory(Var_Count) to 0
    - Increment Dict_Size and Var_Count
    - If either limit reached: OK := False, no modification
    - _Requirements: 14.1, 14.2_

  - [~] 10.3 Add VARIABLE handling in Interpret_Line
    - When "VARIABLE" token is encountered in interpretation mode: read next token as name, call Create_Variable
    - If no name follows VARIABLE: return Compile_Error
    - If Create_Variable fails: return Compile_Error
    - _Requirements: 14.1, 14.2, 16.2_

  - [~] 10.4 Ensure Inst_Var_Addr is handled in Execute_Word
    - Verify the Inst_Var_Addr case implemented in task 2.3 pushes the Operand (variable address) onto the Data_Stack
    - _Requirements: 4.7_

  - [ ]* 10.5 Write property test for variable address uniqueness (Property 5)
    - **Property 5: Variable Address Uniqueness**
    - **Validates: Requirements 2.3, 14.1**

  - [ ]* 10.6 Write property test for store-fetch round trip (Property 6)
    - **Property 6: Store-Fetch Round Trip**
    - **Validates: Requirements 15.1, 15.3**

- [ ] 11. Phase 3 — GNATprove Verification and Integration Tests
  - [~] 11.1 Run GNATprove and resolve all verification conditions for Phase 3
    - Run: `gnatprove -P forth_interpreter.gpr --level=2 --prover=alt-ergo`
    - All VCs must be discharged including variable operations and Create_Variable
    - _Requirements: 20.1, 20.2, 20.3, 20.4_

  - [~] 11.2 Add integration tests for variables in test_integration.adb
    - Test `VARIABLE X 42 X ! X @ .` → prints 42
    - Test `VARIABLE X X @ 1 + X !` (increment pattern)
    - Test invalid address: push out-of-range address, call `!` → Stack_Error
    - Test VARIABLE in colon definition context: `: SETX X ! ; VARIABLE X 99 SETX X @ .` → prints 99
    - _Requirements: 14.1, 15.1, 15.3, 15.4_

- [ ] 12. Checkpoint — Phase 3 Complete
  - Ensure all GNATprove VCs pass with zero unproved, all integration tests pass. Ask the user if questions arise.

- [ ] 13. Final verification and backward compatibility
  - [~] 13.1 Run full GNATprove verification on entire codebase
    - Run: `gnatprove -P forth_interpreter.gpr --level=2 --prover=alt-ergo`
    - Confirm all VCs discharged across all packages (bounded_stacks, forth_vm, forth_interpreter)
    - _Requirements: 20.1, 20.2, 20.3, 20.4, 20.5_

  - [~] 13.2 Run all integration tests and verify backward compatibility
    - All original test cases pass unchanged
    - All new test cases pass
    - Build and run: `gprbuild -P forth_interpreter.gpr test_integration.adb && ./obj/test_integration`
    - _Requirements: 19.1, 19.2, 19.3_

  - [ ]* 13.3 Write property test for existing primitives unaffected (Property 11)
    - **Property 11: Existing Primitives Unaffected**
    - **Validates: Requirements 19.1, 19.2**

  - [ ]* 13.4 Write property test for Code_Space monotonic growth (Property 12)
    - **Property 12: Code_Space Monotonic Growth**
    - **Validates: Requirements 6.1, 7.1, 7.2**

- [ ] 14. Final checkpoint
  - Ensure all GNATprove VCs pass with zero unproved, all integration tests pass, backward compatibility confirmed. Ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation after each phase
- Property tests validate universal correctness properties from the design document
- The primary verification mechanism is GNATprove formal proof, not runtime testing
- Always use: `gnatprove -P forth_interpreter.gpr --level=2 --prover=alt-ergo` (no z3, no cvc5)
- The design specifies an iterative inner interpreter with no Ada-level recursion
- Return stack frames are 2 entries each (Return_PC + End_Addr), max 32 nesting levels
- Fuel counter (Max_Exec_Steps = 10,000) guarantees termination
- Error-path drain loop ensures Return_Stack is empty on all Execute_Word exit paths
