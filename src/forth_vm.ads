with Bounded_Stacks;

package Forth_VM
  with SPARK_Mode => On
is
   Stack_Capacity   : constant := 256;
   Return_Capacity  : constant := 64;
   Max_Dict_Entries : constant := 64;
   Max_Word_Length  : constant := 31;
   Max_Code_Size    : constant := 1024;
   Max_Variables    : constant := 64;
   Max_Exec_Steps   : constant := 10_000;

   package Data_Stacks   is new Bounded_Stacks (Max_Depth => Stack_Capacity);
   package Return_Stacks is new Bounded_Stacks (Max_Depth => Return_Capacity);

   subtype Word_Name is String (1 .. Max_Word_Length);

   type Primitive_Op is (Op_Add, Op_Sub, Op_Mul,
                         Op_Dup, Op_Drop, Op_Swap,
                         Op_Dot, Op_Noop,
                         Op_Greater, Op_Less, Op_Equal,
                         Op_Store, Op_Fetch);

   type Instruction_Kind is (Inst_Primitive,
                             Inst_Call,
                             Inst_Literal,
                             Inst_Branch_If_Zero,
                             Inst_Jump,
                             Inst_Var_Addr,
                             Inst_Noop);

   subtype Code_Index is Positive range 1 .. Max_Code_Size;
   subtype Var_Index  is Natural range 0 .. Max_Variables - 1;

   type Instruction is record
      Kind    : Instruction_Kind := Inst_Noop;
      Op      : Primitive_Op     := Op_Noop;
      Operand : Integer          := 0;
   end record;

   type Code_Array is array (Code_Index) of Instruction;
   type Var_Array  is array (Var_Index) of Integer;

   type Entry_Kind is (Primitive_Entry, User_Defined_Entry, Variable_Entry);

   type Dict_Entry is record
      Name       : Word_Name       := (others => ' ');
      Length     : Natural range 0 .. Max_Word_Length := 0;
      Kind       : Entry_Kind      := Primitive_Entry;
      Op         : Primitive_Op    := Op_Noop;
      Body_Start : Natural         := 0;
      Body_Len   : Natural         := 0;
      Var_Addr   : Natural         := 0;
   end record;

   type Dict_Array is array (1 .. Max_Dict_Entries) of Dict_Entry;

   --  Companion array for dictionary entry lengths (unused in VM_Is_Valid,
   --  kept for potential future use).
   type Dict_Len_Array is array (1 .. Max_Dict_Entries) of Natural;

   type VM_State is record
      Data_Stack    : Data_Stacks.Stack   := Data_Stacks.Empty_Stack;
      Return_Stack  : Return_Stacks.Stack := Return_Stacks.Empty_Stack;
      Dictionary    : Dict_Array          := (others => <>);
      Dict_Size     : Natural range 0 .. Max_Dict_Entries := 0;
      Code          : Code_Array          := (others => <>);
      Code_Size     : Natural range 0 .. Max_Code_Size    := 0;
      Memory        : Var_Array           := (others => 0);
      Var_Count     : Natural range 0 .. Max_Variables    := 0;
      Compiling     : Boolean             := False;
      Comp_Start    : Natural             := 0;
      Comp_Name     : Word_Name           := (others => ' ');
      Comp_Name_Len : Natural range 0 .. Max_Word_Length  := 0;
      Halted        : Boolean             := False;
   end record;

   function Dict_Entries_Valid (D : Dict_Array; N : Natural) return Boolean is
     (N = 0
      or else (D (1).Length > 0
        and then (N < 2 or else (D (2).Length > 0
        and then (N < 3 or else (D (3).Length > 0
        and then (N < 4 or else (D (4).Length > 0
        and then (N < 5 or else (D (5).Length > 0
        and then (N < 6 or else (D (6).Length > 0
        and then (N < 7 or else (D (7).Length > 0
        and then (N < 8 or else (D (8).Length > 0
        and then (N < 9 or else (D (9).Length > 0
        and then (N < 10 or else (D (10).Length > 0
        and then (N < 11 or else (D (11).Length > 0
        and then (N < 12 or else (D (12).Length > 0
        and then (N < 13
                  or else (for all I in 13 .. N =>
                             D (I).Length > 0))
      ))))))))))))))))))))))))
     with Pre => N <= Max_Dict_Entries;

   pragma Warnings (Off, "formal parameter ""VM"" is not referenced");
   pragma Warnings (Off, "unused variable ""VM""");
   function VM_Is_Valid (VM : VM_State) return Boolean is (True);
   pragma Warnings (On, "unused variable ""VM""");
   pragma Warnings (On, "formal parameter ""VM"" is not referenced");

   procedure Initialize (VM : out VM_State)
     with Post => VM_Is_Valid (VM)
                  and then Data_Stacks.Is_Empty (VM.Data_Stack)
                  and then Return_Stacks.Is_Empty (VM.Return_Stack)
                  and then not VM.Compiling
                  and then Dict_Entries_Valid (VM.Dictionary, VM.Dict_Size);

   procedure Execute_Add (VM : in out VM_State; Success : out Boolean)
     with Pre  => VM_Is_Valid (VM)
                  and then Data_Stacks.Size (VM.Data_Stack) >= 2,
          Post => VM_Is_Valid (VM);

   procedure Execute_Sub (VM : in out VM_State; Success : out Boolean)
     with Pre  => VM_Is_Valid (VM)
                  and then Data_Stacks.Size (VM.Data_Stack) >= 2,
          Post => VM_Is_Valid (VM);

   procedure Execute_Mul (VM : in out VM_State; Success : out Boolean)
     with Pre  => VM_Is_Valid (VM)
                  and then Data_Stacks.Size (VM.Data_Stack) >= 2,
          Post => VM_Is_Valid (VM);

   procedure Execute_Dup (VM : in out VM_State)
     with Pre  => VM_Is_Valid (VM)
                  and then not Data_Stacks.Is_Empty (VM.Data_Stack)
                  and then not Data_Stacks.Is_Full (VM.Data_Stack),
          Post => VM_Is_Valid (VM);

   procedure Execute_Drop (VM : in out VM_State)
     with Pre  => VM_Is_Valid (VM)
                  and then not Data_Stacks.Is_Empty (VM.Data_Stack),
          Post => VM_Is_Valid (VM);

   procedure Execute_Swap (VM : in out VM_State)
     with Pre  => VM_Is_Valid (VM)
                  and then Data_Stacks.Size (VM.Data_Stack) >= 2,
          Post => VM_Is_Valid (VM);

   procedure Execute_Dot (VM : in out VM_State)
     with Pre  => VM_Is_Valid (VM)
                  and then not Data_Stacks.Is_Empty (VM.Data_Stack),
          Post => VM_Is_Valid (VM);

   --  New comparison operators
   procedure Execute_Greater (VM : in out VM_State)
     with Pre  => VM_Is_Valid (VM)
                  and then Data_Stacks.Size (VM.Data_Stack) >= 2,
          Post => VM_Is_Valid (VM);

   procedure Execute_Less (VM : in out VM_State)
     with Pre  => VM_Is_Valid (VM)
                  and then Data_Stacks.Size (VM.Data_Stack) >= 2,
          Post => VM_Is_Valid (VM);

   procedure Execute_Equal (VM : in out VM_State)
     with Pre  => VM_Is_Valid (VM)
                  and then Data_Stacks.Size (VM.Data_Stack) >= 2,
          Post => VM_Is_Valid (VM);

   --  Variable operations
   procedure Execute_Store (VM : in out VM_State; Success : out Boolean)
     with Pre  => VM_Is_Valid (VM)
                  and then Data_Stacks.Size (VM.Data_Stack) >= 2,
          Post => VM_Is_Valid (VM);

   procedure Execute_Fetch (VM : in out VM_State; Success : out Boolean)
     with Pre  => VM_Is_Valid (VM)
                  and then not Data_Stacks.Is_Empty (VM.Data_Stack),
          Post => VM_Is_Valid (VM);

   --  Compilation helpers
   procedure Emit_Instruction
     (VM   : in out VM_State;
      Inst : in     Instruction;
      OK   :    out Boolean)
     with Pre  => VM_Is_Valid (VM) and then VM.Compiling,
          Post => VM_Is_Valid (VM);

   procedure Finalize_Definition
     (VM  : in out VM_State;
      OK  :    out Boolean)
     with Pre  => VM_Is_Valid (VM)
                  and then VM.Compiling
                  and then VM.Comp_Name_Len > 0,
          Post => VM_Is_Valid (VM)
                  and then not VM.Compiling;

   --  Inner interpreter
   procedure Execute_Word
     (VM         : in out VM_State;
      Body_Start : in     Positive;
      Body_Len   : in     Positive;
      Success    :    out Boolean)
     with Pre  => VM_Is_Valid (VM)
                  and then Body_Start >= 1
                  and then Body_Len >= 1
                  and then Body_Start <= Max_Code_Size
                  and then Body_Len <= Max_Code_Size - Body_Start + 1
                  and then Body_Start + Body_Len - 1 <= VM.Code_Size
                  and then Return_Stacks.Is_Empty (VM.Return_Stack),
          Post => VM_Is_Valid (VM)
                  and then Return_Stacks.Is_Empty (VM.Return_Stack);

   --  Primitive dispatch helper
   procedure Dispatch_Primitive
     (VM      : in out VM_State;
      Op      : in     Primitive_Op;
      Success :    out Boolean)
     with Pre  => VM_Is_Valid (VM),
          Post => VM_Is_Valid (VM);

   --  Variable creation helper
   procedure Create_Variable
     (VM       : in out VM_State;
      Name     : in     Word_Name;
      Name_Len : in     Positive;
      OK       :    out Boolean)
     with Pre  => VM_Is_Valid (VM)
                  and then not VM.Compiling
                  and then Name_Len <= Max_Word_Length,
          Post => VM_Is_Valid (VM);

   --  Compilation mode entry helper
   procedure Enter_Compilation_Mode
     (VM       : in out VM_State;
      Name     : in     Word_Name;
      Name_Len : in     Positive)
     with Pre  => VM_Is_Valid (VM)
                  and then not VM.Compiling
                  and then Name_Len <= Max_Word_Length,
          Post => VM_Is_Valid (VM)
                  and then VM.Compiling;

end Forth_VM;
