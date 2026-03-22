with Ada.Text_IO;

package body Forth_VM
  with SPARK_Mode => On
is

   Int_Min : constant Long_Long_Integer := Long_Long_Integer (Integer'First);
   Int_Max : constant Long_Long_Integer := Long_Long_Integer (Integer'Last);

   Default_Dict : constant Dict_Array :=
     (1 => (Name   => ('+', others => ' '),
            Length => 1,
            Op     => Op_Add),
      2 => (Name   => ('-', others => ' '),
            Length => 1,
            Op     => Op_Sub),
      3 => (Name   => ('*', others => ' '),
            Length => 1,
            Op     => Op_Mul),
      4 => (Name   => ('D', 'U', 'P', others => ' '),
            Length => 3,
            Op     => Op_Dup),
      5 => (Name   => ('D', 'R', 'O', 'P', others => ' '),
            Length => 4,
            Op     => Op_Drop),
      6 => (Name   => ('S', 'W', 'A', 'P', others => ' '),
            Length => 4,
            Op     => Op_Swap),
      7 => (Name   => ('.', others => ' '),
            Length => 1,
            Op     => Op_Dot),
      others => <>);

   procedure Initialize (VM : out VM_State) is
   begin
      VM.Data_Stack := Data_Stacks.Empty_Stack;
      VM.Dictionary := Default_Dict;
      VM.Dict_Size  := 7;
      VM.Halted     := False;

      pragma Assert (VM.Dictionary (1).Length = 1);
      pragma Assert (VM.Dictionary (2).Length = 1);
      pragma Assert (VM.Dictionary (3).Length = 1);
      pragma Assert (VM.Dictionary (4).Length = 3);
      pragma Assert (VM.Dictionary (5).Length = 4);
      pragma Assert (VM.Dictionary (6).Length = 4);
      pragma Assert (VM.Dictionary (7).Length = 1);
   end Initialize;

   procedure Execute_Add (VM : in out VM_State; Success : out Boolean) is
      A, B : Integer;
      R    : Long_Long_Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, A);
      Data_Stacks.Pop (VM.Data_Stack, B);
      R := Long_Long_Integer (A) + Long_Long_Integer (B);
      if R in Int_Min .. Int_Max then
         Data_Stacks.Push (VM.Data_Stack, Integer (R));
         Success := True;
      else
         Data_Stacks.Push (VM.Data_Stack, B);
         Data_Stacks.Push (VM.Data_Stack, A);
         Success := False;
      end if;
   end Execute_Add;

   procedure Execute_Sub (VM : in out VM_State; Success : out Boolean) is
      A, B : Integer;
      R    : Long_Long_Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, A);
      Data_Stacks.Pop (VM.Data_Stack, B);
      R := Long_Long_Integer (B) - Long_Long_Integer (A);
      if R in Int_Min .. Int_Max then
         Data_Stacks.Push (VM.Data_Stack, Integer (R));
         Success := True;
      else
         Data_Stacks.Push (VM.Data_Stack, B);
         Data_Stacks.Push (VM.Data_Stack, A);
         Success := False;
      end if;
   end Execute_Sub;

   procedure Execute_Mul (VM : in out VM_State; Success : out Boolean) is
      A, B : Integer;
      R    : Long_Long_Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, A);
      Data_Stacks.Pop (VM.Data_Stack, B);
      R := Long_Long_Integer (A) * Long_Long_Integer (B);
      if R in Int_Min .. Int_Max then
         Data_Stacks.Push (VM.Data_Stack, Integer (R));
         Success := True;
      else
         Data_Stacks.Push (VM.Data_Stack, B);
         Data_Stacks.Push (VM.Data_Stack, A);
         Success := False;
      end if;
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

   procedure Execute_Dot (VM : in out VM_State)
     with SPARK_Mode => Off
   is
      V : Integer;
   begin
      Data_Stacks.Pop (VM.Data_Stack, V);
      Ada.Text_IO.Put (Integer'Image (V) & " ");
   end Execute_Dot;

end Forth_VM;
