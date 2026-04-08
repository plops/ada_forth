# Supported Forth Subset

This interpreter implements a small, line-oriented subset of Forth. The goal of this document is to describe the subset as it actually behaves today, including a few implementation-specific limits and quirks.

## 1. Execution Model

- The interpreter is interactive and processes one input line at a time.
- A line may contain integer literals, built-in words, variable names, and user-defined words.
- The data stack persists across lines until values are consumed or the VM is reinitialized.
- User-defined words and variables persist once created.
- A blank input line exits the REPL.

Example:

```forth
10 20 30
```

After this line finishes, the stack contains `10 20 30`, with `30` on top.

## 2. Lexical Rules

- Input lines are limited to 256 characters.
- Tokens are separated only by the ASCII space character `' '`.
- Multiple spaces are allowed.
- Tabs are not treated as separators.
- Token matching is case-insensitive for built-ins, control-flow words, variables, and user-defined words.
- Token and word-name storage is limited to 31 characters.
- Tokens longer than 31 characters are silently truncated to their first 31 characters.

Examples:

```forth
dup
DUP
DuP
```

All three forms execute the same word.

## 3. Data Types and Truth Values

- The only data type is a signed host `Integer`.
- Integer literals are parsed in decimal.
- A leading `-` is allowed.
- A leading `+` is not supported.
- Non-decimal forms such as hex are not supported.
- Comparison words return `-1` for true and `0` for false.
- At runtime, `IF` treats `0` as false and any nonzero value as true.

Examples:

```forth
-5
123
5 3 >
3 5 >
```

The last two lines leave `-1` and `0` respectively.

## 4. Data Stack

- The data stack holds up to 256 integers.
- Stack underflow and overflow are reported as `Stack_Error`.
- Arithmetic overflow is also reported as `Stack_Error`.

Supported stack effects use standard Forth notation:

- `n` means an integer.
- `addr` means a variable address.
- Rightmost item is the top of stack.

## 5. Built-In Words

### 5.1 Arithmetic

`+` `( a b -- a+b )`

`-` `( a b -- a-b )`

`*` `( a b -- a*b )`

Examples:

```forth
3 4 + .
5 DUP * .
1 2 SWAP - .
```

### 5.2 Stack Manipulation

`DUP` `( x -- x x )`

`DROP` `( x -- )`

`SWAP` `( a b -- b a )`

Examples:

```forth
7 DUP * .
1 2 SWAP . .
```

### 5.3 Comparison

`>` `( a b -- flag )`

`<` `( a b -- flag )`

`=` `( a b -- flag )`

Semantics:

- `a b >` is true when `a > b`
- `a b <` is true when `a < b`
- `a b =` is true when `a = b`

Examples:

```forth
5 3 > .
3 5 < .
7 7 = .
```

Each example prints `-1`.

### 5.4 Variables

`!` `( value addr -- )`

`@` `( addr -- value )`

Examples:

```forth
VARIABLE X
42 X !
X @ .
```

### 5.5 Output

`.` `( x -- )`

Semantics:

- Pops the top stack item.
- Prints it immediately.
- Positive values are printed with the host Ada image format, so they appear with a leading space.

Example:

```forth
25 .
```

In the REPL this appears as:

```text
 25  OK
```

## 6. User-Defined Words

New words are defined with colon syntax:

```forth
: NAME body ;
```

Rules:

- `:` must be followed by a name.
- The body may contain literals, built-in words, variable names, and previously defined user words.
- The body must not be empty.
- The definition becomes callable only after `;`.
- Unknown tokens inside a definition cause `Compile_Error`.

Examples:

```forth
: SQUARE DUP * ;
5 SQUARE .
```

```forth
: CUBE DUP DUP * * ;
3 CUBE .
```

## 7. Conditionals

The only supported control-flow words are:

- `IF`
- `ELSE`
- `THEN`

These are compile-only words. They are valid only while compiling a colon definition.

Runtime semantics:

- `IF` pops one flag.
- If the flag is `0`, execution jumps to the matching `ELSE` or `THEN`.
- If the flag is nonzero, execution continues with the true branch.

Examples:

```forth
: ABS DUP 0 < IF -1 * THEN ;
-5 ABS .
5 ABS .
```

```forth
: SIGN DUP 0 > IF DROP 1 ELSE DUP 0 < IF DROP -1 ELSE DROP 0 THEN THEN ;
5 SIGN .
-3 SIGN .
0 SIGN .
```

Current limits:

- Nested `IF` structures are limited to 16 levels while compiling one input line.
- `IF`, `ELSE`, and `THEN` must match correctly or compilation fails.
- `IF`/`ELSE`/`THEN` are not interpreted at the top level.

## 8. Variables

Variables are created with:

```forth
VARIABLE name
```

Semantics:

- Creating a variable adds a named cell initialized to `0`.
- Executing the variable name pushes its address.
- `!` stores into that address.
- `@` fetches from that address.
- Variable addresses are numeric and currently range from `0` upward.
- There can be at most 64 variables.

Examples:

```forth
VARIABLE X
X @ .
```

This prints `0`.

```forth
VARIABLE X
X @ 1 + X !
X @ .
```

This prints `1`.

Notes:

- Variables must be declared at the top level.
- `VARIABLE` inside a colon definition is not supported.
- Previously declared variables may be referenced inside colon definitions.

## 9. Names, Lookup, and Redefinition

- Built-in words, variables, and user-defined words share one dictionary.
- Dictionary lookup is case-insensitive.
- The dictionary holds at most 64 entries total.
- The 12 built-in words occupy the first 12 entries.
- That leaves room for 52 combined user words and variables.

Important current behavior:

- Lookup returns the first matching dictionary entry, not the most recent one.
- As a result, redefinition does not shadow an earlier definition.
- In practice, names should be treated as unique.

Example:

```forth
: X 1 ;
: X 2 ;
X .
```

This still executes the first `X`, not the second one.

The same warning applies across kinds. A variable and a word should not reuse the same name.

## 10. Compilation Across Lines

Compilation state persists across lines until `;` is seen, so straight-line definitions may be continued across multiple REPL inputs.

Example:

```forth
: TWICE
DUP +
;
```

However, conditional matching is tracked per interpreted line in the current implementation. In practice:

- multi-line straight-line definitions work
- multi-line `IF ... ELSE ... THEN` definitions should be avoided

Write complete conditional structures on one line.

## 11. Resource Limits

- Maximum input line length: 256 characters
- Maximum token length: 31 characters
- Maximum word name length: 31 characters
- Data stack capacity: 256 items
- Return stack capacity: 64 items
- Dictionary capacity: 64 entries total
- Variable capacity: 64 cells
- Compiled code capacity: 1024 instructions total
- Execution fuel limit for a user-word invocation: 10,000 instruction steps

Effects of limits:

- Exceeding stack or arithmetic limits yields `Stack_Error`.
- Exceeding dictionary, variable, code, or control-flow compile limits yields `Compile_Error`.
- Exceeding the execution fuel limit yields `Stack_Error`.

## 12. Error Categories

The interpreter reports three practical error classes during normal use:

- `Unknown_Word`: an unrecognized token at top level
- `Stack_Error`: stack underflow, stack overflow, arithmetic overflow, invalid variable access, or execution failure
- `Compile_Error`: malformed or unsupported definitions

Examples:

```forth
FOOBAR
```

Results in `Unknown_Word`.

```forth
+
```

Results in `Stack_Error`.

```forth
: BAD NONEXISTENT ;
```

Results in `Compile_Error`.

## 13. Unsupported Forth Features

This interpreter does not currently support:

- division or modulo
- `OVER`, `ROT`, `.S`, `EMIT`, `CR`
- loops such as `BEGIN`, `UNTIL`, `DO`, `LOOP`
- constants
- strings
- comments
- immediate words
- `CREATE ... DOES>`
- forward references
- true recursion during definition
- standard Forth redefinition semantics

## 14. Small Cookbook

Square a number:

```forth
: SQUARE DUP * ;
9 SQUARE .
```

Absolute value:

```forth
: ABS DUP 0 < IF -1 * THEN ;
-12 ABS .
```

Use a variable as a counter:

```forth
VARIABLE COUNT
COUNT @ 1 + COUNT !
COUNT @ .
```

Branch on a comparison result:

```forth
: NONNEG DUP 0 < IF DROP 0 THEN ;
5 NONNEG .
-3 NONNEG .
```
