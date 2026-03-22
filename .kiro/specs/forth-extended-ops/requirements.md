# Requirements Document

## Introduction

This document specifies the requirements for extending the existing SPARK-verified Forth interpreter with three major capabilities: user-defined words (colon definitions), conditional control flow (IF/THEN/ELSE), and variables (VARIABLE, `!`, `@`). All new code operates under `SPARK_Mode => On` with zero dynamic memory allocation and formal contracts provable by GNATprove using only the alt-ergo prover. The extension preserves the existing VM_Is_Valid invariant and all 186 previously discharged verification conditions.

## Glossary

- **VM_State**: The flat record encapsulating the complete Forth virtual machine state, extended with return stack, code space, variable memory, and compilation state fields
- **VM_Is_Valid**: An expression function returning True when the VM_State satisfies all structural invariants, extended to cover new fields
- **Data_Stack**: A bounded integer stack (capacity 256) for operand storage, instantiated from Bounded_Stacks
- **Return_Stack**: A bounded integer stack (capacity 64) for nested word call/return context, instantiated from Bounded_Stacks
- **Code_Space**: A flat array of up to 1024 Instruction records storing compiled word bodies
- **Instruction**: A record with Kind (discriminant), Op (for primitives), and Operand (literal value, jump target, call target, or variable address)
- **Instruction_Kind**: An enumeration: Inst_Primitive, Inst_Call, Inst_Literal, Inst_Branch_If_Zero, Inst_Jump, Inst_Var_Addr, Inst_Noop
- **Dict_Entry**: A record mapping a word name to its definition, extended with Entry_Kind, Body_Start, Body_Len, and Var_Addr fields
- **Entry_Kind**: An enumeration distinguishing Primitive_Entry, User_Defined_Entry, and Variable_Entry
- **Primitive_Op**: The enumeration of built-in operations, extended with Op_Greater, Op_Less, Op_Equal, Op_Store, Op_Fetch
- **Colon_Definition**: A user-defined word created by `: NAME body ;` syntax, compiled into Code_Space
- **Compilation_Mode**: The interpreter state where tokens are compiled into instructions rather than executed
- **Control_Flow_Stack**: A local compile-time stack used to track IF/ELSE/THEN branch target addresses during compilation
- **Variable_Memory**: A flat array of 64 integer cells addressed by Var_Index (0-based)
- **Fuel_Counter**: An instruction step counter (Max_Exec_Steps = 10,000) guaranteeing termination of Execute_Word
- **Return_Frame**: A pair of return stack entries (Return_PC, End_Addr) pushed by Inst_Call and popped on word body completion
- **Inner_Interpreter**: The Execute_Word procedure that iteratively fetches and executes instructions from Code_Space
- **Outer_Interpreter**: The Interpret_Line procedure that tokenizes input and dispatches to compilation or execution
- **GNATprove**: The SPARK formal verification engine that discharges verification conditions
- **AoRTE**: Absence of Runtime Errors — the guarantee that no runtime exception can occur
- **Interpret_Result**: An enumeration of outcomes: OK, Unknown_Word, Stack_Error, Compile_Error, Halted

## Requirements

### Requirement 1: Extended VM State Structure

**User Story:** As an embedded systems developer, I want the VM state extended with return stack, code space, variable memory, and compilation state fields in a single flat record, so that the interpreter can support user-defined words, control flow, and variables without heap allocation.

#### Acceptance Criteria

1. THE VM_State record SHALL contain a Return_Stack field instantiated from Bounded_Stacks with a capacity of 64
2. THE VM_State record SHALL contain a Code field as a fixed-size array of up to 1024 Instruction records and a Code_Size field constrained to the range 0 through Max_Code_Size
3. THE VM_State record SHALL contain a Memory field as a fixed-size array of 64 integer cells and a Var_Count field constrained to the range 0 through Max_Variables
4. THE VM_State record SHALL contain compilation state fields: Compiling (Boolean), Comp_Start (Natural), Comp_Name (Word_Name), and Comp_Name_Len (Natural range 0 through Max_Word_Length)
5. THE Forth_VM package SHALL use zero access types and zero dynamic memory allocation in all new code

### Requirement 2: Extended Dictionary Entry

**User Story:** As a developer, I want dictionary entries to distinguish between primitives, user-defined words, and variables, so that the interpreter can dispatch each kind correctly.

#### Acceptance Criteria

1. THE Dict_Entry record SHALL contain a Kind field of type Entry_Kind with values Primitive_Entry, User_Defined_Entry, and Variable_Entry
2. WHEN Kind equals User_Defined_Entry, THE Dict_Entry SHALL contain valid Body_Start (>= 1) and Body_Len (>= 1) fields referencing a contiguous slice within Code_Space where Body_Start + Body_Len - 1 is at most Code_Size
3. WHEN Kind equals Variable_Entry, THE Dict_Entry SHALL contain a Var_Addr field in the range 0 through Var_Count minus 1
4. WHEN Kind equals Primitive_Entry, THE Dict_Entry SHALL contain an Op field identifying the primitive operation

### Requirement 3: Extended VM_Is_Valid Invariant

**User Story:** As a verification engineer, I want the VM validity predicate extended to cover all new state fields, so that all operations can be proven to preserve structural integrity.

#### Acceptance Criteria

1. THE VM_Is_Valid function SHALL return True only when Dict_Size is within 0 through Max_Dict_Entries and all active dictionary entries at indices 1 through Dict_Size have Length greater than zero
2. THE VM_Is_Valid function SHALL validate that Code_Size is within 0 through Max_Code_Size
3. THE VM_Is_Valid function SHALL validate that Var_Count is within 0 through Max_Variables
4. WHEN VM_Is_Valid returns True and Compiling equals True, THE VM_State SHALL have Comp_Name_Len greater than zero
5. THE Dict_Entries_Valid function SHALL extend the existing unrolled pattern to cover new built-in entries for comparison and variable operations

### Requirement 4: Instruction Type and Code Space

**User Story:** As a developer, I want a typed instruction set stored in a flat code array, so that compiled word bodies can be represented without dynamic allocation.

#### Acceptance Criteria

1. THE Instruction record SHALL contain a Kind field of type Instruction_Kind with values Inst_Primitive, Inst_Call, Inst_Literal, Inst_Branch_If_Zero, Inst_Jump, Inst_Var_Addr, and Inst_Noop
2. WHEN Kind equals Inst_Primitive, THE Instruction SHALL use the Op field to identify the primitive operation to execute
3. WHEN Kind equals Inst_Call, THE Instruction SHALL use the Operand field to hold the dictionary index of the user-defined word to call
4. WHEN Kind equals Inst_Literal, THE Instruction SHALL use the Operand field to hold the integer value to push onto the Data_Stack
5. WHEN Kind equals Inst_Branch_If_Zero, THE Instruction SHALL use the Operand field to hold the absolute target index in Code_Space to jump to when the top-of-stack value equals zero
6. WHEN Kind equals Inst_Jump, THE Instruction SHALL use the Operand field to hold the absolute target index in Code_Space for unconditional jump
7. WHEN Kind equals Inst_Var_Addr, THE Instruction SHALL use the Operand field to hold the variable address (index into Variable_Memory)

### Requirement 5: Compilation Mode — Colon Definitions

**User Story:** As a Forth user, I want to define new words using `: NAME body ;` syntax, so that I can extend the interpreter's vocabulary with reusable word definitions.

#### Acceptance Criteria

1. WHEN the Outer_Interpreter encounters a `:` token in interpretation mode, THE Forth_Interpreter SHALL enter compilation mode, read the next token as the word name, and record it in Comp_Name and Comp_Name_Len
2. WHILE in compilation mode, THE Forth_Interpreter SHALL compile each token into an Instruction in Code_Space rather than executing the token
3. WHEN the Outer_Interpreter encounters a `;` token in compilation mode, THE Forth_Interpreter SHALL finalize the definition by creating a new Dict_Entry of kind User_Defined_Entry with Body_Start and Body_Len referencing the compiled instructions, and exit compilation mode
4. WHEN a colon definition is finalized successfully, THE Forth_Interpreter SHALL increment Dict_Size by exactly one and set Compiling to False
5. WHEN a known primitive word is encountered during compilation, THE Forth_Interpreter SHALL emit an Inst_Primitive instruction with the corresponding Op value
6. WHEN a known user-defined word is encountered during compilation, THE Forth_Interpreter SHALL emit an Inst_Call instruction with the dictionary index as Operand
7. WHEN an integer literal is encountered during compilation, THE Forth_Interpreter SHALL emit an Inst_Literal instruction with the parsed value as Operand

### Requirement 6: Emit Instruction

**User Story:** As a developer, I want a helper procedure to append instructions to Code_Space during compilation, so that compilation logic remains modular and provable.

#### Acceptance Criteria

1. WHEN Emit_Instruction is called with a valid VM_State in compilation mode and Code_Size is less than Max_Code_Size, THE Forth_VM SHALL increment Code_Size by one, store the instruction at the new Code_Size index, and return OK as True
2. IF Code_Size equals Max_Code_Size when Emit_Instruction is called, THEN THE Forth_VM SHALL return OK as False without modifying Code_Space
3. WHEN Emit_Instruction completes, THE VM_State SHALL satisfy VM_Is_Valid regardless of the OK result

### Requirement 7: Finalize Definition

**User Story:** As a developer, I want the `;` handler to create a well-formed dictionary entry and exit compilation mode, so that compiled words are correctly registered.

#### Acceptance Criteria

1. WHEN Finalize_Definition is called with a valid compiling VM_State and Dict_Size is less than Max_Dict_Entries, THE Forth_VM SHALL create a new Dict_Entry of kind User_Defined_Entry, increment Dict_Size, and set Compiling to False
2. IF Dict_Size equals Max_Dict_Entries when Finalize_Definition is called, THEN THE Forth_VM SHALL set Compiling to False, roll back Code_Size to Comp_Start, and return OK as False
3. WHEN Finalize_Definition completes, THE VM_State SHALL satisfy VM_Is_Valid and Compiling SHALL equal False

### Requirement 8: Inner Interpreter — Execute_Word

**User Story:** As a Forth user, I want user-defined words to execute by iteratively fetching and dispatching instructions from Code_Space, so that word execution is provably terminating and supports nested calls.

#### Acceptance Criteria

1. WHEN Execute_Word is called with a valid body range (Body_Start >= 1, Body_Len >= 1, Body_Start + Body_Len - 1 <= Code_Size) and an empty Return_Stack, THE Inner_Interpreter SHALL iteratively fetch and execute instructions from Code_Space starting at Body_Start
2. WHEN an Inst_Call instruction is encountered and the Return_Stack has room for 2 entries, THE Inner_Interpreter SHALL push the current return context (Return_PC and End_Addr) onto the Return_Stack and jump to the callee's body
3. WHEN the program counter reaches the end of a word body and the Return_Stack is not empty, THE Inner_Interpreter SHALL pop the saved Return_PC and End_Addr to resume the caller's execution
4. WHEN the program counter reaches the end of the top-level word body and the Return_Stack is empty, THE Inner_Interpreter SHALL complete successfully
5. WHEN Execute_Word completes (successfully or not), THE VM_State SHALL satisfy VM_Is_Valid and the Return_Stack SHALL be empty
6. THE Execute_Word procedure SHALL maintain loop invariants asserting VM_Is_Valid, valid PC bounds, valid End_Addr bounds, and Steps within Max_Exec_Steps at every iteration boundary

### Requirement 9: Termination Guarantee — Fuel Counter

**User Story:** As a safety engineer, I want Execute_Word to terminate within a bounded number of steps, so that infinite recursion and infinite loops from backward branches cannot hang the interpreter.

#### Acceptance Criteria

1. THE Inner_Interpreter SHALL track total instructions executed in a fuel counter (Steps) during each Execute_Word invocation
2. WHEN Steps reaches Max_Exec_Steps (10,000), THE Inner_Interpreter SHALL set Success to False and exit the execution loop
3. WHEN execution is aborted due to fuel exhaustion, THE Inner_Interpreter SHALL drain the Return_Stack to empty before returning, preserving VM_Is_Valid

### Requirement 10: Return Stack Frame Management

**User Story:** As a developer, I want nested word calls managed via an explicit return stack with 2-entry frames, so that call/return context is tracked without Ada-level recursion.

#### Acceptance Criteria

1. WHEN Inst_Call is executed, THE Inner_Interpreter SHALL push exactly 2 values onto the Return_Stack: the return PC (PC + 1) and the current End_Addr
2. WHEN returning from a nested call, THE Inner_Interpreter SHALL pop exactly 2 values from the Return_Stack and restore PC and End_Addr
3. IF the Return_Stack has fewer than 2 free entries when Inst_Call is encountered, THEN THE Inner_Interpreter SHALL set Success to False (nesting overflow)
4. THE maximum nesting depth SHALL be 32 levels (Return_Capacity of 64 divided by 2 entries per frame)

### Requirement 11: Error-Path Return Stack Drain

**User Story:** As a verification engineer, I want the return stack drained to empty on all error paths in Execute_Word, so that the postcondition (Return_Stack is empty) holds on every exit.

#### Acceptance Criteria

1. WHEN Execute_Word exits with Success equal to False, THE Inner_Interpreter SHALL execute a drain loop that pops all remaining entries from the Return_Stack
2. WHEN the drain loop completes, THE Return_Stack SHALL be empty and VM_Is_Valid SHALL hold
3. THE drain loop SHALL maintain a loop invariant asserting VM_Is_Valid at every iteration boundary

### Requirement 12: Comparison Operators

**User Story:** As a Forth user, I want comparison operators (>, <, =) that produce Forth boolean values, so that I can use them with IF/THEN/ELSE control flow.

#### Acceptance Criteria

1. WHEN Execute_Greater is called with a valid VM_State having at least 2 elements on the Data_Stack, THE Forth_VM SHALL pop two values (A then B), push -1 if B is greater than A, and push 0 otherwise
2. WHEN Execute_Less is called with a valid VM_State having at least 2 elements on the Data_Stack, THE Forth_VM SHALL pop two values (A then B), push -1 if B is less than A, and push 0 otherwise
3. WHEN Execute_Equal is called with a valid VM_State having at least 2 elements on the Data_Stack, THE Forth_VM SHALL pop two values, push -1 if they are equal, and push 0 otherwise
4. WHEN any comparison operator completes, THE VM_State SHALL satisfy VM_Is_Valid with a net stack effect of minus one (two popped, one pushed)

### Requirement 13: Control Flow Compilation — IF/ELSE/THEN

**User Story:** As a Forth user, I want IF/ELSE/THEN conditional branching in colon definitions, so that I can write words with conditional logic.

#### Acceptance Criteria

1. WHEN the token IF is encountered during compilation, THE Forth_Interpreter SHALL emit an Inst_Branch_If_Zero instruction with a placeholder target and record the code position on a compile-time control flow stack
2. WHEN the token ELSE is encountered during compilation, THE Forth_Interpreter SHALL emit an Inst_Jump instruction with a placeholder target, patch the preceding IF branch target to the instruction after the Inst_Jump, and record the new code position on the control flow stack
3. WHEN the token THEN is encountered during compilation, THE Forth_Interpreter SHALL patch the most recent branch target (from IF or ELSE) to the current Code_Size plus one
4. WHEN IF/THEN is compiled without ELSE, THE Forth_Interpreter SHALL emit only Inst_Branch_If_Zero (no Inst_Jump) with the target pointing past the THEN position
5. WHEN an Inst_Branch_If_Zero is executed and the top-of-stack value equals zero, THE Inner_Interpreter SHALL jump to the target address specified in the Operand field
6. WHEN an Inst_Branch_If_Zero is executed and the top-of-stack value does not equal zero, THE Inner_Interpreter SHALL continue to the next instruction (fall through)
7. WHEN an Inst_Jump is executed, THE Inner_Interpreter SHALL unconditionally jump to the target address specified in the Operand field

### Requirement 14: Variable Declaration

**User Story:** As a Forth user, I want to declare named variables using `VARIABLE name` syntax, so that I can store and retrieve values by name.

#### Acceptance Criteria

1. WHEN the token VARIABLE is encountered in interpretation mode followed by a name token, THE Forth_Interpreter SHALL create a new Dict_Entry of kind Variable_Entry with a unique Var_Addr equal to the current Var_Count, initialize Memory at that address to zero, and increment both Dict_Size and Var_Count
2. IF Dict_Size equals Max_Dict_Entries or Var_Count equals Max_Variables when VARIABLE is encountered, THEN THE Forth_Interpreter SHALL return Compile_Error without modifying the VM_State
3. WHEN a Variable_Entry name is encountered during interpretation, THE Forth_Interpreter SHALL push the variable's Var_Addr onto the Data_Stack

### Requirement 15: Variable Store and Fetch Operations

**User Story:** As a Forth user, I want `!` (store) and `@` (fetch) operations to write and read variable memory by address, so that I can manipulate variable values on the stack.

#### Acceptance Criteria

1. WHEN Execute_Store is called with a valid VM_State having at least 2 elements on the Data_Stack, THE Forth_VM SHALL pop the address (top) and value (second), and if the address is in the range 0 through Var_Count minus 1, store the value in Memory at that address and set Success to True
2. IF the address popped by Execute_Store is outside the range 0 through Var_Count minus 1, THEN THE Forth_VM SHALL restore the Data_Stack to its original state and set Success to False
3. WHEN Execute_Fetch is called with a valid VM_State having a non-empty Data_Stack, THE Forth_VM SHALL pop the address (top), and if the address is in the range 0 through Var_Count minus 1, push the value from Memory at that address and set Success to True
4. IF the address popped by Execute_Fetch is outside the range 0 through Var_Count minus 1, THEN THE Forth_VM SHALL restore the Data_Stack to its original state and set Success to False
5. WHEN Execute_Store or Execute_Fetch completes, THE VM_State SHALL satisfy VM_Is_Valid regardless of the Success result

### Requirement 16: Extended Outer Interpreter Dispatch

**User Story:** As a Forth user, I want the outer interpreter to dispatch user-defined words, variable references, and compilation mode tokens in addition to primitives and integer literals, so that all new features integrate seamlessly.

#### Acceptance Criteria

1. WHEN a token matches a User_Defined_Entry in the Dictionary during interpretation mode, THE Forth_Interpreter SHALL call Execute_Word with the entry's Body_Start and Body_Len
2. WHEN a token matches a Variable_Entry in the Dictionary during interpretation mode, THE Forth_Interpreter SHALL push the entry's Var_Addr onto the Data_Stack
3. WHILE in compilation mode, THE Forth_Interpreter SHALL compile tokens into Code_Space and handle `:`, `;`, IF, ELSE, THEN as compilation directives rather than executing them
4. THE Interpret_Line procedure SHALL maintain a loop invariant asserting VM_Is_Valid at every iteration boundary
5. THE Interpret_Result type SHALL include a Compile_Error value for compilation failures

### Requirement 17: Compilation Error Handling

**User Story:** As a Forth user, I want clear error reporting when compilation fails, so that I can understand and correct my word definitions.

#### Acceptance Criteria

1. IF Code_Space is full during compilation (Code_Size equals Max_Code_Size), THEN THE Forth_Interpreter SHALL abandon the definition, roll back Code_Size to Comp_Start, set Compiling to False, and return Compile_Error
2. IF the Dictionary is full when `;` is encountered, THEN THE Forth_Interpreter SHALL roll back Code_Size to Comp_Start, set Compiling to False, and return Compile_Error
3. IF a token during compilation is neither a known word nor a valid integer literal, THEN THE Forth_Interpreter SHALL abandon the definition and return Compile_Error
4. IF `:` is the last token on the line with no name following, THEN THE Forth_Interpreter SHALL not enter compilation mode and SHALL return Compile_Error
5. IF `;` is reached with unresolved control flow (non-empty control flow stack), THEN THE Forth_Interpreter SHALL abandon the definition, roll back Code_Size, and return Compile_Error

### Requirement 18: Execution Error Handling in Execute_Word

**User Story:** As a Forth user, I want runtime errors during word execution to be handled gracefully, so that the VM remains in a valid state after any failure.

#### Acceptance Criteria

1. IF a primitive operation fails during Execute_Word (stack underflow or overflow), THEN THE Inner_Interpreter SHALL set Success to False and exit the execution loop
2. IF an Inst_Branch_If_Zero or Inst_Jump has a target outside the valid body range, THEN THE Inner_Interpreter SHALL set Success to False and exit the execution loop
3. IF an Inst_Call references an invalid dictionary index or a non-User_Defined_Entry, THEN THE Inner_Interpreter SHALL set Success to False and exit the execution loop
4. IF the Data_Stack is empty when Inst_Branch_If_Zero needs to pop a value, THEN THE Inner_Interpreter SHALL set Success to False and exit the execution loop
5. WHEN Execute_Word exits with Success equal to False, THE Inner_Interpreter SHALL drain the Return_Stack and preserve VM_Is_Valid

### Requirement 19: Backward Compatibility

**User Story:** As an existing user, I want all previously working Forth programs to continue working identically after the extension, so that the upgrade is non-breaking.

#### Acceptance Criteria

1. THE behavior of the 7 original primitive operations (Op_Add, Op_Sub, Op_Mul, Op_Dup, Op_Drop, Op_Swap, Op_Dot) SHALL remain identical to the pre-extension behavior
2. THE extended Dict_Entry record and Entry_Kind field SHALL not alter the dispatch of Primitive_Entry words
3. WHEN Initialize is called, THE Forth_VM SHALL populate the Dictionary with all original primitive entries plus new built-in entries for comparison and variable operations, with VM_Is_Valid returning True and both Data_Stack and Return_Stack empty

### Requirement 20: SPARK Verification and Formal Guarantees

**User Story:** As a safety engineer, I want all new code to pass GNATprove with zero unproved verification conditions using only the alt-ergo prover, so that absence of runtime errors and functional correctness are formally guaranteed.

#### Acceptance Criteria

1. THE Bounded_Stacks, Forth_VM, and Forth_Interpreter packages SHALL each compile with SPARK_Mode set to On for all new code
2. WHEN GNATprove is run at level 2 with the alt-ergo prover, THE system SHALL discharge all verification conditions for absence of runtime errors in all new code
3. WHEN GNATprove is run, THE system SHALL discharge all verification conditions for functional correctness contracts (preconditions, postconditions, and loop invariants) in all new code
4. THE system SHALL use zero access types across all SPARK-verified packages, ensuring no dynamic memory allocation
5. THE Execute_Word procedure SHALL use an iterative loop with no Ada-level recursion, avoiding the need for Subprogram_Variant annotations
