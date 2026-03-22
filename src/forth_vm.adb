with Ada.Text_IO;

package body Forth_VM
  with SPARK_Mode => On
is

   function Make_Entry
     (Name_Str : String;
      Op       : Primitive_Op) return Dict_Entry
   is
      E : Dict_Entry;
   begin
      E.Name := (others => ' ');
      E.Name (1 .. Name_Str'Length) := Name_Str;
      E.Length := Name_Str'Length;
      E.Op := Op;
      return E;
   end Make_Entry;

   procedure Initialize (VM : out VM_State) is
   begin
      VM.Data_Stack := Data_Stacks.Empty_Stack;
      VM.Dictionary := (others => <>);
      VM.Dict_Size  := 7;
      VM.Halted     := False;

      VM.Dictionary (1) := Make_Entry ("+", Op_Add);
      VM.Dictionary (2) := Make_Entry ("-", Op_Sub);
      VM.Dictionary (3) := Make_Entry ("*", Op_Mul);
      VM.Dictionary (4) := Make_Entry ("DUP", Op_Dup);
      VM.Dictionary (5) := Make_Entry ("DROP", Op_Drop);
      VM.Dictionary (6) := Make_Entry ("SWAP", Op_Swap);
      VM.Dictionary (7) := Make_Entry (".", Op_Dot);
   end Initialize;

   procedure Execute_Add (VM : in out VM_State) is
      A, B : Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, A);
      Data_Stacks.Pop (VM.Data_Stack, B);
      Data_Stacks.Push (VM.Data_Stack, A + B);
   end Execute_Add;

   procedure Execute_Sub (VM : in out VM_State) is
      A, B : Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, A);
      Data_Stacks.Pop (VM.Data_Stack, B);
      Data_Stacks.Push (VM.Data_Stack, B - A);
   end Execute_Sub;

   procedure Execute_Mul (VM : in out VM_State) is
      A, B : Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, A);
      Data_Stacks.Pop (VM.Data_Stack, B);
      Data_Stacks.Push (VM.Data_Stack, A * B);
   end Execute_Mul;

   procedure Execute_Dup (VM : in out VM_State) is
      V : Integer;
   begin
      V := Data_Stacks.Peek (VM.Data_Stack);
      Data_Stacks.Push (VM.Data_Stack, V);
   end Execute_Dup;

   procedure Execute_Drop (VM : in out VM_State) is
      Discard : Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, Discard);
   end Execute_Drop;

   procedure Execute_Swap (VM : in out VM_State) is
      A, B : Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, A);
      Data_Stacks.Pop (VM.Data_Stack, B);
      Data_Stacks.Push (VM.Data_Stack, A);
      Data_Stacks.Push (VM.Data_Stack, B);
   end Execute_Swap;

   procedure Execute_Dot (VM : in out VM_State) is
      V : Integer;

      procedure Put_Int (Value : Integer)
        with SPARK_Mode => Off
      is
      begin
         Ada.Text_IO.Put (Integer'Image (Value) & " ");
      end Put_Int;

   begin
      Data_Stacks.Pop (VM.Data_Stack, V);
      Put_Int (V);
   end Execute_Dot;

end Forth_VM;
