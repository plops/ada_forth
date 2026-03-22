with Bounded_Stacks;

package Forth_VM
  with SPARK_Mode => On
is
   Stack_Capacity   : constant := 256;
   Max_Dict_Entries : constant := 64;
   Max_Word_Length   : constant := 31;

   package Data_Stacks is new Bounded_Stacks (Max_Depth => Stack_Capacity);

   subtype Word_Name is String (1 .. Max_Word_Length);

   type Primitive_Op is (Op_Add, Op_Sub, Op_Mul,
                         Op_Dup, Op_Drop, Op_Swap,
                         Op_Dot, Op_Noop);

   type Dict_Entry is record
      Name   : Word_Name := (others => ' ');
      Length : Natural range 0 .. Max_Word_Length := 0;
      Op     : Primitive_Op := Op_Noop;
   end record;

   type Dict_Array is array (1 .. Max_Dict_Entries) of Dict_Entry;

   type VM_State is record
      Data_Stack : Data_Stacks.Stack := Data_Stacks.Empty_Stack;
      Dictionary : Dict_Array := (others => <>);
      Dict_Size  : Natural range 0 .. Max_Dict_Entries := 0;
      Halted     : Boolean := False;
   end record;

   function Dict_Entries_Valid (D : Dict_Array; N : Natural) return Boolean is
     (N = 0
      or else (N >= 1 and then D (1).Length > 0
               and then (N < 2 or else (D (2).Length > 0
               and then (N < 3 or else (D (3).Length > 0
               and then (N < 4 or else (D (4).Length > 0
               and then (N < 5 or else (D (5).Length > 0
               and then (N < 6 or else (D (6).Length > 0
               and then (N < 7 or else (D (7).Length > 0
               and then (N < 8
                         or else (for all I in 8 .. N =>
                                    D (I).Length > 0))))))))))))))))
     with Pre => N <= Max_Dict_Entries;

   function VM_Is_Valid (VM : VM_State) return Boolean is
     (Dict_Entries_Valid (VM.Dictionary, VM.Dict_Size));

   procedure Initialize (VM : out VM_State)
     with Post => VM_Is_Valid (VM)
                  and then Data_Stacks.Is_Empty (VM.Data_Stack);

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

end Forth_VM;
