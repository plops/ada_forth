# Requirements Document

## Introduction

This document specifies the requirements for a SPARK-verified minimal Forth interpreter implemented in Ada 2012 / SPARK 2014. The system provides a formally verified bounded stack, a Forth virtual machine with primitive word execution, and an outer interpreter loop. All verified code operates under `SPARK_Mode => On` with zero dynamic memory allocation and formal contracts sufficient for GNATprove to discharge all verification conditions.

## Glossary

- **Bounded_Stack**: A generic, statically-sized integer stack with formal contracts, parameterized by maximum depth
- **VM_State**: A flat record encapsulating the complete Forth virtual machine state (data stack, dictionary, dictionary size, halted flag)
- **VM_Is_Valid**: An expression function that returns True when the VM_State satisfies all structural invariants
- **Dictionary**: A fixed-size array of Dict_Entry records mapping word names to primitive operations
- **Dict_Entry**: A record containing a fixed-length name buffer, actual name length, and associated primitive operation
- **Primitive_Op**: An enumeration of built-in Forth operations (Op_Add, Op_Sub, Op_Mul, Op_Dup, Op_Drop, Op_Swap, Op_Dot, Op_Noop)
- **Token**: A record containing a fixed-length text buffer and actual token length, extracted from an input line
- **Interpret_Result**: An enumeration of possible outcomes from interpreting a line (OK, Unknown_Word, Stack_Error, Halted)
- **GNATprove**: The SPARK formal verification engine that discharges verification conditions using SMT solvers
- **Ghost_Function**: A SPARK function annotated with the Ghost aspect, used only in contracts and erased at runtime
- **Loop_Invariant**: A SPARK pragma asserting a property that holds at every iteration boundary of a loop
- **Frame_Condition**: A postcondition clause guaranteeing that elements not involved in an operation remain unchanged
- **SPARK_Mode**: A configuration pragma that enables SPARK verification for a compilation unit
- **AoRTE**: Absence of Runtime Errors — the guarantee that no runtime exception can occur

## Requirements

### Requirement 1: Bounded Stack Data Structure

**User Story:** As an embedded systems developer, I want a generic bounded stack with formal contracts, so that I can use it as the Forth data stack with proven absence of overflow and underflow.

#### Acceptance Criteria

1. THE Bounded_Stacks package SHALL be a generic SPARK package parameterized by a positive Max_Depth value, with SPARK_Mode set to On
2. WHEN a Stack is created, THE Bounded_Stack SHALL initialize with Top equal to zero and all Data elements set to zero
3. THE Is_Empty function SHALL return True when the Stack Top equals zero, and False otherwise
4. THE Is_Full function SHALL return True when the Stack Top equals Max_Depth, and False otherwise
5. THE Size function SHALL return the current value of the Stack Top field

### Requirement 2: Stack Push Operation

**User Story:** As a developer, I want to push integer values onto the bounded stack with formal guarantees, so that the stack grows correctly and existing elements are preserved.

#### Acceptance Criteria

1. WHEN Push is called on a Stack that is not full, THE Bounded_Stack SHALL increment the Stack Size by exactly one
2. WHEN Push is called with a Value, THE Bounded_Stack SHALL set the new top element equal to Value, verifiable via Peek
3. WHEN Push is called, THE Bounded_Stack SHALL preserve all previously existing elements at their original positions (frame condition via Element_At quantification)
4. THE Push procedure SHALL carry a precondition requiring that the Stack is not full

### Requirement 3: Stack Pop Operation

**User Story:** As a developer, I want to pop integer values from the bounded stack with formal guarantees, so that the stack shrinks correctly and the correct value is returned.

#### Acceptance Criteria

1. WHEN Pop is called on a Stack that is not empty, THE Bounded_Stack SHALL decrement the Stack Size by exactly one
2. WHEN Pop is called, THE Bounded_Stack SHALL return the value that was on top of the Stack before the call
3. WHEN Pop is called, THE Bounded_Stack SHALL preserve all remaining elements at their original positions (frame condition via Element_At quantification)
4. THE Pop procedure SHALL carry a precondition requiring that the Stack is not empty

### Requirement 4: Stack Ghost Function

**User Story:** As a verification engineer, I want a ghost function for element access, so that quantified postconditions can reference arbitrary stack positions without runtime cost.

#### Acceptance Criteria

1. THE Element_At ghost function SHALL accept a Stack and a one-based Positive index and return the Integer at that logical position
2. THE Element_At function SHALL carry a precondition requiring the index is between 1 and Size of the Stack inclusive
3. THE Element_At function SHALL be annotated with the Ghost aspect so it is erased at runtime

### Requirement 5: VM State Structure

**User Story:** As an embedded systems developer, I want the Forth VM state encapsulated in a single flat record with no heap allocation, so that the interpreter is suitable for bare-metal environments.

#### Acceptance Criteria

1. THE VM_State record SHALL contain a Data_Stack field instantiated from Bounded_Stacks with a capacity of 256
2. THE VM_State record SHALL contain a Dictionary field as a fixed-size array of up to 64 Dict_Entry records
3. THE VM_State record SHALL contain a Dict_Size field constrained to the range 0 through Max_Dict_Entries
4. THE VM_State record SHALL contain a Halted Boolean field defaulting to False
5. THE Forth_VM package SHALL use zero access types and zero dynamic memory allocation

### Requirement 6: VM Validity Invariant

**User Story:** As a verification engineer, I want a VM validity predicate, so that all operations can be proven to preserve the structural integrity of the VM state.

#### Acceptance Criteria

1. THE VM_Is_Valid function SHALL return True only when Dict_Size is within 0 through Max_Dict_Entries and all active dictionary entries at indices 1 through Dict_Size have Length greater than zero
2. WHEN Initialize is called, THE Forth_VM SHALL produce a VM_State where VM_Is_Valid returns True and the Data_Stack is empty
3. THE VM_Is_Valid function SHALL be an expression function that GNATprove can inline and reason about

### Requirement 7: Primitive Word Executors — Arithmetic

**User Story:** As a Forth user, I want arithmetic primitives (add, subtract, multiply) that pop two operands and push the result, so that I can perform integer calculations safely without risking runtime overflow.

#### Acceptance Criteria

1. WHEN Execute_Add is called with a valid VM_State having at least 2 elements on the Data_Stack, THE Forth_VM SHALL pop the top two values, compute their sum, and if the result is within Integer range push it and set Success to True, otherwise restore the original stack state and set Success to False, preserving VM validity in both cases
2. WHEN Execute_Sub is called with a valid VM_State having at least 2 elements on the Data_Stack, THE Forth_VM SHALL pop the top two values, compute their difference, and if the result is within Integer range push it and set Success to True, otherwise restore the original stack state and set Success to False, preserving VM validity in both cases
3. WHEN Execute_Mul is called with a valid VM_State having at least 2 elements on the Data_Stack, THE Forth_VM SHALL pop the top two values, compute their product, and if the result is within Integer range push it and set Success to True, otherwise restore the original stack state and set Success to False, preserving VM validity in both cases
4. THE Execute_Add, Execute_Sub, and Execute_Mul procedures SHALL each carry a precondition requiring VM_Is_Valid and Data_Stack Size of at least 2
5. THE Execute_Add, Execute_Sub, and Execute_Mul procedures SHALL use Long_Long_Integer intermediate arithmetic to detect overflow before narrowing to Integer, guaranteeing absence of runtime errors (AoRTE)

### Requirement 8: Primitive Word Executors — Stack Manipulation

**User Story:** As a Forth user, I want stack manipulation primitives (DUP, DROP, SWAP), so that I can rearrange values on the data stack.

#### Acceptance Criteria

1. WHEN Execute_Dup is called with a valid VM_State having a non-empty and non-full Data_Stack, THE Forth_VM SHALL push a copy of the top element and preserve VM validity
2. WHEN Execute_Drop is called with a valid VM_State having a non-empty Data_Stack, THE Forth_VM SHALL remove the top element and preserve VM validity
3. WHEN Execute_Swap is called with a valid VM_State having at least 2 elements on the Data_Stack, THE Forth_VM SHALL exchange the top two elements and preserve VM validity
4. WHEN Execute_Dot is called with a valid VM_State having a non-empty Data_Stack, THE Forth_VM SHALL remove the top element for output and preserve VM validity

### Requirement 9: Dictionary Structure and Initialization

**User Story:** As a developer, I want the dictionary pre-populated with all built-in primitives at initialization, so that the interpreter can resolve word names to operations without runtime registration.

#### Acceptance Criteria

1. WHEN Initialize is called, THE Forth_VM SHALL populate the Dictionary with entries for all seven primitive words (add, subtract, multiply, DUP, DROP, SWAP, dot)
2. THE Dict_Entry record SHALL store a fixed-length Word_Name buffer of 31 characters, an actual Length in range 0 through Max_Word_Length, and a Primitive_Op value
3. WHEN a Dict_Entry is active (index within 1 through Dict_Size), THE Dict_Entry SHALL have Length greater than zero and Op not equal to Op_Noop

### Requirement 10: Token Reader

**User Story:** As a developer, I want a tokenizer that extracts whitespace-delimited tokens from a fixed-size line buffer, so that the interpreter can process Forth input without heap allocation.

#### Acceptance Criteria

1. WHEN a Line_Buffer and valid length are provided, THE Token_Reader SHALL extract whitespace-delimited tokens sequentially using only fixed-size buffers
2. THE Token record SHALL store text in a fixed buffer of Max_Token_Length (31) characters with an actual Length field
3. WHEN whitespace is encountered between tokens, THE Token_Reader SHALL skip all contiguous whitespace characters before extracting the next token

### Requirement 11: Outer Interpreter Dispatch Loop

**User Story:** As a Forth user, I want to type a line of Forth words and have them executed in order, so that I can interact with the interpreter.

#### Acceptance Criteria

1. WHEN Interpret_Line is called with a valid VM_State and a Line_Buffer with length not exceeding Max_Line_Length, THE Forth_Interpreter SHALL process each token in left-to-right order
2. WHEN a token matches a Dictionary entry, THE Forth_Interpreter SHALL check that the Data_Stack has enough operands for the matched primitive before dispatching execution
3. WHEN a token does not match any Dictionary entry, THE Forth_Interpreter SHALL attempt to parse the token as an integer literal and push the value onto the Data_Stack
4. THE Interpret_Line procedure SHALL maintain a loop invariant asserting VM_Is_Valid at every iteration boundary
5. THE Interpret_Line procedure SHALL maintain a loop invariant asserting the scanning position Pos is within the range 1 through Len plus one

### Requirement 12: Interpreter Error Handling

**User Story:** As a Forth user, I want clear error reporting when something goes wrong, so that I can understand and correct my input.

#### Acceptance Criteria

1. IF a primitive requires more operands than are present on the Data_Stack, THEN THE Forth_Interpreter SHALL return Stack_Error without executing the primitive and without modifying the VM_State
2. IF an integer literal is parsed but the Data_Stack is full, THEN THE Forth_Interpreter SHALL return Stack_Error without pushing and without modifying the VM_State
3. IF a token is neither found in the Dictionary nor parseable as an integer literal, THEN THE Forth_Interpreter SHALL return Unknown_Word without modifying the VM_State
4. WHEN Interpret_Line completes without error, THE Forth_Interpreter SHALL return OK

### Requirement 13: SPARK Verification and Safety Guarantees

**User Story:** As a safety engineer, I want all verified code to pass GNATprove with zero unproved verification conditions, so that absence of runtime errors and functional correctness are formally guaranteed.

#### Acceptance Criteria

1. THE Bounded_Stacks, Forth_VM, and Forth_Interpreter packages SHALL each compile with SPARK_Mode set to On
2. WHEN GNATprove is run at level 2 with z3 and cvc5 solvers, THE system SHALL discharge all verification conditions for absence of runtime errors
3. WHEN GNATprove is run, THE system SHALL discharge all verification conditions for functional correctness contracts (preconditions, postconditions, and loop invariants)
4. THE system SHALL use zero access types across all SPARK-verified packages, ensuring no dynamic memory allocation

### Requirement 14: Static Memory Footprint

**User Story:** As an embedded systems developer, I want the interpreter to have a known, bounded memory footprint, so that it can be deployed on resource-constrained targets.

#### Acceptance Criteria

1. THE Data_Stack SHALL occupy at most Stack_Capacity multiplied by the size of Integer bytes of static storage
2. THE Dictionary SHALL occupy at most Max_Dict_Entries multiplied by the size of Dict_Entry bytes of static storage
3. THE Line_Buffer SHALL occupy at most Max_Line_Length bytes of static storage
4. THE system SHALL use only stack-allocated and statically-sized objects with no heap allocation
